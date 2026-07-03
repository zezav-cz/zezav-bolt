# TODO

## Infrastructure

- [ ] **Fail2ban in profile::base** — `profile::fail2ban` exists but is not included in base. Should be baseline for all nodes since SSH is exposed on every server. Requires adding a fail2ban module pin to `bolt-project.yaml` first (the class includes a `fail2ban` module that is not installed yet).
- [ ] **Re-enable monitoring::node_exporter** — the `monitoring` module is complete (binary install with checksum verification, systemd unit) but commented out in `data/nodes/z01.de.yaml` and not classified anywhere.
- [ ] **Headscale firewall tightening** — `podman_quadlet::container::headscale` opens HTTPS/HTTP/WireGuard/STUN across the `public`, `block`, `drop`, `internal`, and `trusted` zones. `internal` and `trusted` should be removed (behavioral change, verify VPN clients still connect).
- [ ] **Log rotation audit** — Verify nginx logs (especially custom vhost logs) are properly rotated. Check if the nginx module handles this or if custom logrotate configs are needed.
- [ ] **DNS resolver pinning** — Manage `/etc/resolv.conf` explicitly instead of relying on DHCP defaults. Ensure consistent, reliable DNS across all nodes.
- [ ] **Verify FQDN assumption** — per-node hiera resolves `nodes/%{facts.networking.fqdn}.yaml` and the files are named `z01.de.yaml` etc., while inventory URIs are `z0X.de.zezav.cz`. Confirm `facter networking.fqdn` on a live node really returns `z01.de`; if it returns the full name, per-node hiera silently never loads.

## Code quality (round 2)

- [ ] **Tests** — no specs exist. Add `rspec-puppet` (via `puppetlabs_spec_helper`) for the `site/` modules and `bolt_spec/plans` for `zezav_bolt::install`; wire up `mise run test` and extend `mise run ci` to fmt + lint + test.
- [ ] **Secrets management** — `web::private_zezav_cz::oidc_session_secret` sits plaintext in `data/nodes/z01.de.yaml`. Introduce hiera-eyaml (or similar) and rotate the secret when migrating.
- [ ] **Cross-class coupling** — `web` and `podman_quadlet::container::headscale` read `$profile::server_firewall::public_zone` directly, relying on `profile::base` include order. Replace with explicit class parameters or a hiera lookup.
- [ ] **doc/ structure** — create `doc/architecture.md`, `doc/development.md`, `doc/operations.md`, and `doc/decisions/` (ADRs). Move the architecture description out of `CLAUDE.md` into `doc/architecture.md`.

## Tooling (round 2)

- [ ] **Dagger refactor** — `.dagger/main.go` re-implements the lint commands instead of calling `mise run` tasks; the CI container's Ruby comes unpinned from `alpine:3.19` (differs from mise's 3.2.11); editorconfig-checker's version is duplicated as a Go string literal. Rework the pipeline to install mise in the container and run `mise run ci`.
- [ ] **Fix `zazav` → `zezav` naming** — `dagger.json` (`"name": "zazav-bolt"`) and `.dagger/go.mod` (`module dagger/zazav-bolt`) carry a typo of the project name; requires `dagger develop` to regenerate the SDK.
