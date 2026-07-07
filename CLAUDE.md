# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Puppet Bolt project (`zezav_bolt`) managing 3 Debian cloud servers (z01, z02, z03 at `*.de.zezav.cz`). Orchestrates configuration via Bolt plans that run `puppet apply` over SSH as root.

## Common Commands

```bash
# Setup (first time)
mise install && bundle install && mise run modules && lefthook install

# Install Puppet modules from Puppetfile into .modules/
mise run modules          # or: bundle exec bolt module install

# Deploy to a node (interactive node selection)
bundle exec bolt plan run zezav_bolt::install -t <node>

# Deploy in noop/dry-run mode
bundle exec bolt plan run zezav_bolt::install -t <node> noop=true

# Lint / format / test
mise run lint             # puppet-lint + parser validate + prettier + editorconfig-checker
mise run fmt              # auto-fix lint issues
mise run test             # rspec-puppet unit tests (see doc/testing.md)
mise run test:parallel    # rspec-puppet unit tests on all CPU cores
mise run ci               # all checks (what CI runs)

# Run a single spec (args pass through to rspec)
mise run test -- spec/classes/profile/sysctl_spec.rb
```

## Architecture

### Node Classification

Nodes are classified in `manifests/nodes.pp` — each node block declares which profiles to include. Unknown nodes trigger an error. Per-node hiera data lives in `data/nodes/<fqdn>.yaml`, common defaults in `data/common.yaml`.

Hiera hierarchy (`hiera.yaml`): per-node FQDN → common.

### Site Modules (`site/`)

All custom Puppet code lives under `site/` as self-contained modules:

- **profile/** — Base infrastructure: accounts, SSH, sudo, APT, firewalld, tailscale, certbot, sysctl, timesync, unattended upgrades (fail2ban exists but is not yet classified — see TODO.md)
- **web/** — Nginx sites (zezav.cz, blog, dir, private with OIDC)
- **podman_quadlet/** — Systemd quadlet containers (headscale, minecraft; prometheus/grafana/alertmanager observability stack on z03, localhost-only) with podman networks
- **monitoring/** — Node exporter binary management with architecture-specific checksums (enabled on all nodes via `profile::node_exporter`)
- **general/** — MOTD and utilities

Each module can have its own `data/` directory for module-level hiera data.

### Plans (`plans/`)

- **install.pp** — Main deployment plan. Applies `manifests/nodes.pp` via `apply_prep` + `apply`. Supports `noop` parameter. Logs apply results per-node to `logs/`.

### Bolt Configuration

`bolt-project.yaml` registers available plans, pins module versions (duplicated from Puppetfile for Bolt's resolver), and sets apply settings (evaltrace, show_diff).

External modules install to `.modules/` (via Puppetfile). The module path includes `site/` for custom modules.

### CI/CD

Dagger pipeline (`.dagger/`, Go-based) runs checks via GitHub Actions (`.github/workflows/checks.yml`): all `+check` functions fan out from one shared container image, and a separate `dagger call test` job runs the rspec suite (too slow for the check fan-out). Lefthook runs staged-file linters on pre-commit and the full `dagger check '**'` suite on pre-push (Dagger talks to rootless podman via `DOCKER_HOST` in the gitignored `mise.local.toml`).

## Puppet Conventions

- Firewall management uses `firewalld` (not iptables) — rich rules with zones
- Containers use podman with systemd quadlets, not docker
- Target inventory is in `inventory.yaml` (SSH transport, root user)
- Puppet 8 comes from the `openvox` gem (via `openbolt` in the Gemfile, with `BOLT_GEM=true` env var) — don't add the `puppet` gem alongside it
