# TODO

## Infrastructure

- [ ] **Fail2ban in profile::base** — `profile::fail2ban` exists but is not included in base. Should be baseline for all nodes since SSH is exposed on every server. Requires adding a fail2ban module pin to `bolt-project.yaml` first (the class includes a `fail2ban` module that is not installed yet).
- [x] **Re-enable monitoring::node_exporter** — enabled on all nodes via `profile::node_exporter` included in `profile::base`.
- [ ] **profile::tailscale removed from base** — `include profile::tailscale` in `base.pp` is commented out for now, so the Tailscale client is no longer managed on any node. Decide whether to re-enable it in base, classify it per-node via hiera, or drop the class. Note `podman_quadlet::container::minecraft` on z02 firewalls by a `tailscale_ip`, which assumes the tailnet keeps working.
- [ ] **Re-enable profile::server_firewall** — the `include profile::server_firewall` in `base.pp` is commented out, so no node currently has a managed firewall. Re-enable deliberately (noop review first); relates to the "Cross-class coupling" item below (`web` and headscale read `$profile::server_firewall::public_zone`). When firewalld is back, also set `firewall_driver => '"firewalld"'` in `profile::podman`'s `containers_options` so netavark programs its rules via firewalld (zone integration, reload-safe) — it is deliberately unset while firewalld is unmanaged. Also flip back `podman_quadlet::container::headscale::fw` (defaults to off because `firewall-cmd` is absent on the nodes), and re-add HTTP/HTTPS openings for the `web` module deliberately (its firewalld rules were removed entirely).
- [ ] **Headscale firewall tightening** — `podman_quadlet::container::headscale` (with `fw => true`, currently off by default) opens HTTPS/HTTP/WireGuard/STUN across the `public`, `block`, `drop`, `internal`, and `trusted` zones. `internal` and `trusted` should be removed (behavioral change, verify VPN clients still connect). Revisit when re-enabling profile::server_firewall.
- [ ] **Log rotation audit** — Verify nginx logs (especially custom vhost logs) are properly rotated. Check if the nginx module handles this or if custom logrotate configs are needed.
- [ ] **DNS resolver pinning** — Manage `/etc/resolv.conf` explicitly instead of relying on DHCP defaults. Ensure consistent, reliable DNS across all nodes.
- [ ] **Verify FQDN assumption** — per-node hiera resolves `nodes/%{facts.networking.fqdn}.yaml` and the files are named `z01.de.yaml` etc., while inventory URIs are `z0X.de.zezav.cz`. Confirm `facter networking.fqdn` on a live node really returns `z01.de`; if it returns the full name, per-node hiera silently never loads.

## Code quality (round 2)

- [x] **Tests** — rspec-puppet specs cover all `site/` classes/defines and `zezav_bolt::nodes` on Debian 12+13 (`mise run test`, see `doc/testing.md`); `mise run ci` now runs fmt + lint + test. Still open: `bolt_spec/plans` coverage for `zezav_bolt::install`, and a `profile::fail2ban` spec once its module is pinned.
- [ ] **Secrets management** — `web::private_zezav_cz::oidc_session_secret` sits plaintext in `data/nodes/z01.de.yaml`. Introduce hiera-eyaml (or similar) and rotate the secret when migrating.
- [x] **Cross-class coupling** — resolved: `web`'s firewalld rules (the only reader of `$profile::server_firewall::public_zone`) were deleted; headscale never read it (it uses literal zone names).
- [ ] **doc/ structure** — create `doc/architecture.md`, `doc/development.md`, `doc/operations.md`, and `doc/decisions/` (ADRs). Move the architecture description out of `CLAUDE.md` into `doc/architecture.md`.

## Tooling (round 2)

- [ ] **Dagger refactor** — `.dagger/main.go` re-implements the lint commands instead of calling `mise run` tasks; the CI container's Ruby comes unpinned from `alpine:3.19` (differs from mise's 3.2.11); editorconfig-checker's version is duplicated as a Go string literal. Rework the pipeline to install mise in the container and run `mise run ci`.
- [ ] **Fix `zazav` → `zezav` naming** — `dagger.json` (`"name": "zazav-bolt"`) and `.dagger/go.mod` (`module dagger/zazav-bolt`) carry a typo of the project name; requires `dagger develop` to regenerate the SDK.
