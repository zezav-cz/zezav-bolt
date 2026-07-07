# Podman DNAT Hairpin Loop: Container Cannot Reach External Port 443

**Date:** 2026-05-06  
**Affected node:** z03.de.zezav.cz  
**Symptom:** headscale container fails to start — `connection refused` fetching DERP map from `controlplane.tailscale.com:443`

---

## Symptom

```
FTL Headscale ran into an error and had to shut down.
error="failed to get DERPMap: Get \"https://controlplane.tailscale.com/derpmap/default\":
dial tcp 192.200.0.116:443: connect: connection refused"
```

The host itself could reach `controlplane.tailscale.com` fine. A vanilla `podman run --rm -it nicolaka/netshoot` container also had full internet access. Only the headscale quadlet service failed.

---

## What Made This Confusing

- The error says **"connection refused"** (TCP RST), not "no route to host" or timeout. Connection refused from a public internet address feels impossible from a firewall-drop perspective — firewalls typically silently drop or REJECT with ICMP, not RST.
- The host had internet access. A generic container had internet access. Only _this specific container_ failed, pointing to something unique about it.
- The firewall (`firewalld`, nftables backend) had a `block` default zone and podman interfaces were excluded from named zones — a plausible firewall culprit. But this was a red herring; the `netavark_zone` in firewalld was correctly set up by podman, and generic containers worked fine.

---

## Diagnosis with pwru

[pwru](https://github.com/cilium/pwru) (packet, where are you) traces every kernel network function that touches a given packet using eBPF. It was the key tool that revealed the actual drop point.

Command run:

```bash
./pwru --output-tuple 'src net 10.88.0.0/16 and tcp dst port 443'
```

Abbreviated trace of the SYN packet from headscale trying to reach `192.200.0.x:443`:

```
NETNS        IFACE       FUNC
4026532525   (veth)      ip_local_out            ← packet leaves container
4026532525   (veth)      ip_output
4026532525   (veth)      ip_finish_output2
4026532525   (veth)      __dev_queue_xmit
4026532525   (veth)      dev_hard_start_xmit
4026532525   (veth)      __dev_forward_skb        ← crosses veth into host ns
──────────────────────────────────────────────────
4026531840   podman0     ip_rcv                   ← arrives in host netns on podman0
4026531840   podman0     ip_rcv_core
4026531840   podman0     nf_hook_slow             ← PREROUTING hook runs
4026531840   podman0     nf_checksum
4026531840   podman0     nf_ip_checksum
4026531840   podman0     skb_ensure_writable      ← NAT is about to modify the packet
4026531840   podman0     skb_ensure_writable
                         (trace ends here)
```

**Key observation:** `ip_forward` never appears. The packet enters the host network namespace, hits the PREROUTING netfilter hook, and vanishes. `skb_ensure_writable` is called by the NAT subsystem immediately before it rewrites a packet header — its presence in PREROUTING confirms a DNAT rule fired and modified the destination.

---

## Root Cause: DNAT Hairpin Loop

### How podman/netavark sets up port forwarding

When you publish a container port with `--publish 0.0.0.0:443:4443/tcp`, netavark registers a DNAT rule in the host's nftables PREROUTING chain (inside the `inet netavark` table):

```
# Conceptually (simplified):
chain PREROUTING {
    tcp dport 443 dnat to 10.88.0.41:4443
}
```

`0.0.0.0` means **all interfaces** — the rule matches any packet arriving in the host netns destined for port 443, regardless of which interface it came from.

### The hairpin

When the headscale container (at `10.88.0.41`) makes an outbound TCP connection to `controlplane.tailscale.com:443`, the packet's journey is:

```
[container 10.88.0.41]
    SYN → 192.200.0.x:443
          ↓ (exits via veth)
[host netns, podman0]
    PREROUTING fires
    Rule: tcp dport 443 → dnat to 10.88.0.41:4443
    Destination rewritten: 192.200.0.x:443 → 10.88.0.41:4443
          ↓ (routing decision: dst=10.88.0.41, send back into podman0)
[container 10.88.0.41, port 4443]
    Receives unexpected SYN (port 4443 not yet listening / wrong state)
    → kernel sends TCP RST
          ↓
[container TCP stack]
    SYN sent, RST received → "connection refused"
```

The container's own outbound SYN to port 443 is intercepted by the DNAT rule and looped back to the container's own listening port. This is the **hairpin NAT problem**.

### Why generic containers are unaffected

A plain `podman run` with no published ports creates no DNAT rules at all. Those containers' outbound connections to port 443 pass straight through PREROUTING unchallenged and are forwarded to eth0 normally.

### Why `0.0.0.0` is the culprit

If the DNAT rule were interface-specific — matching only traffic arriving on `eth0` — then `podman0` traffic would be invisible to it. The `0.0.0.0` binding instructs netavark to make the rule apply to all interfaces, which is what causes the loop.

---

## Fix

### Concept

Bind the published port to the **server's specific external IP** instead of `0.0.0.0`. Netavark then generates:

```
daddr <external-ip> tcp dport 443 dnat to 10.88.0.41:4443
```

This rule only fires when traffic is destined _for the server's own IP_. Outbound container traffic going to `192.200.0.x:443` has a different destination and never matches — no hairpin.

Netavark has no built-in per-interface filter option; specific-IP binding is the supported way to achieve the equivalent.

### Changes made

**`site/podman_quadlet/manifests/container.pp`** — added optional `bind_addr` key to `public_ports` entries (defaults to `0.0.0.0`):

```puppet
$public_port_args = $public_ports.map |$pp| {
  $proto = pick($pp['protocol'], 'tcp')
  $addr  = pick($pp['bind_addr'], '0.0.0.0')
  "--publish ${addr}:${pp['port']}:${pp['container_port']}/${proto}"
}
```

**`site/podman_quadlet/manifests/container/headscale.pp`** — bind the HTTPS port to the node's primary external IP via Facter:

```puppet
public_ports => [
  { 'port' => $http_port,  'container_port' => 80,   'protocol' => 'tcp' },
  { 'port' => $https_port, 'container_port' => 4443, 'protocol' => 'tcp',
    'bind_addr' => $facts['networking']['ip'] },
],
```

Port 80 (for the ACME HTTP-01 inbound challenge) is left on `0.0.0.0` — the container never makes outbound connections on port 80, so there is no hairpin risk.

**`site/profile/manifests/server_firewall.pp`** — open ports 443 and 80 in the firewall when `headscale_enabled`:

```puppet
if $headscale_enabled {
  firewalld_service { 'Allow HTTPS - headscale':
    ensure  => 'present',
    zone    => $public_zone,
    service => 'https',
  }
  firewalld_service { 'Allow HTTP - headscale ACME':
    ensure  => 'present',
    zone    => $public_zone,
    service => 'http',
  }
}
```

---

## General Rule

Any container that **both** publishes a port `N` on the host **and** makes outbound connections to port `N` on external servers will experience a DNAT hairpin loop when published to `0.0.0.0`. Common cases:

| Container role                    | Published port | Outbound port | Affected? |
| --------------------------------- | -------------- | ------------- | --------- |
| HTTPS server fetching remote APIs | 443            | 443           | **Yes**   |
| SMTP server relaying mail         | 25             | 25            | **Yes**   |
| DNS resolver                      | 53             | 53            | **Yes**   |
| HTTP-only server                  | 80             | 443           | No        |
| Database                          | 5432           | (none)        | No        |

The fix is always the same: bind the host-side port to the server's external IP so the DNAT rule is destination-specific rather than catch-all.

---

## Tools Used

- **[pwru](https://github.com/cilium/pwru)** — eBPF-based packet tracer. Traces all kernel functions touching an skb. Essential for diagnosing where in the network stack a packet disappears. The absence of `ip_forward` in the trace immediately pointed to PREROUTING consuming the packet.
- `firewall-cmd --get-active-zones` — confirmed zone/interface assignments
- `nft list ruleset` — showed the nftables chains and the final REJECT in FORWARD (useful context, though not the actual cause here)
