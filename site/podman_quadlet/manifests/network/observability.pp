# @summary Shared podman network for the observability stack
#
# Bridge network with a fixed subnet: containers on it resolve each other
# by name (netavark DNS is enabled on custom networks), and the host is
# reachable at the deterministic gateway address 10.90.0.1 — used by
# Prometheus to scrape the host's node_exporter.
class podman_quadlet::network::observability {
  podman_quadlet::network { 'observability':
    subnet  => '10.90.0.0/24',
    gateway => '10.90.0.1',
  }
}
