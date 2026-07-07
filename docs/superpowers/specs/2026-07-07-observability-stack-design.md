# Observability Stack (Prometheus + Grafana + Alertmanager) on z03

**Status:** Approved
**Date:** 2026-07-07

## Goal

Run Prometheus, Grafana, and Alertmanager as podman quadlet containers on
z03.de, following the repo's existing `podman_quadlet::container::*` pattern
(headscale, minecraft). The stack must be moveable to another node by editing
hiera only. No public exposure: all host ports bind to `127.0.0.1`; UIs are
reached via SSH tunnel.

## Scope decisions

- **Scrape targets:** z03-local only for now — the host's node_exporter plus
  the stack's own components. z01/z02 come later once a network path
  (Tailscale or firewall openings) exists; out of scope here.
- **UI access:** SSH tunnel (`ssh -L 3000:localhost:3000 z03...`). No reverse
  proxy, no extra auth. Grafana keeps its default admin first-login flow.
- **Alerting:** Alertmanager → Telegram (native receiver). Bot token stored
  as plaintext hiera in `data/nodes/z03.de.yaml`, consistent with the
  existing `oidc_session_secret`; both migrate when the secrets-management
  TODO lands.
- **Alert rules:** a small starter set to prove the pipeline end-to-end.

## Structure

Four new classes in `site/podman_quadlet/manifests/`:

| Class                                     | Purpose                                                           |
| ----------------------------------------- | ----------------------------------------------------------------- |
| `podman_quadlet::network::observability`  | Wrapper class declaring the shared `observability` podman network |
| `podman_quadlet::container::prometheus`   | Prometheus server container + config + rules                      |
| `podman_quadlet::container::alertmanager` | Alertmanager container + config (Telegram receiver)               |
| `podman_quadlet::container::grafana`      | Grafana container + datasource provisioning                       |

Each container class `include`s the network wrapper, so the node's hiera
`classes` list only names the three containers; `include` deduplicates the
network declaration. The wrapper fills the currently empty
`manifests/network/` directory.

The network uses a **fixed subnet** `10.90.0.0/24`. Containers reach each
other by DNS name (`prometheus`, `alertmanager`, `grafana` — netavark DNS is
enabled on custom networks), and Prometheus scrapes the **host's**
node_exporter at the deterministic gateway address `10.90.0.1:9100`
(node_exporter listens on `0.0.0.0`).

Conventions (headscale pattern): configs under `/etc/<service>/` rendered
from EPP templates in `site/podman_quadlet/templates/container/`; data under
`/var/lib/<service>/`; images pinned to exact versions (current stable
versions verified at implementation time).

## Containers

### Prometheus (`docker.io/prom/prometheus`, 3.x line)

- Port `127.0.0.1:9090` (via the define's `ports` param, which enforces
  localhost binding).
- Data: `/var/lib/prometheus` (owner UID/GID 65534 — the image's `nobody`
  user) mounted to `/prometheus`.
- Config `/etc/prometheus/prometheus.yml` (EPP), scrape jobs:
  - `prometheus` → `localhost:9090`
  - `node` → `10.90.0.1:9100` (host node_exporter via network gateway)
  - `alertmanager` → `alertmanager:9093`
  - `grafana` → `grafana:3000` (native `/metrics`)
- `alerting` block → `alertmanager:9093`; `rule_files` →
  `/etc/prometheus/alerts.yml`.
- Class params: `image`, `active`, `port` (default 9090), `retention`
  (default `'15d'`, passed as `--storage.tsdb.retention.time`).

### Alertmanager (`docker.io/prom/alertmanager`, 0.28.x line)

- Port `127.0.0.1:9093`.
- Data: `/var/lib/alertmanager` (UID/GID 65534) — silences and notification
  log.
- Config `/etc/alertmanager/alertmanager.yml` (EPP), mode `0600` (embeds the
  bot token). Single route → single `telegram` receiver; grouping
  `group_by: [alertname]`, `repeat_interval: 4h`.
- Class params: `telegram_bot_token` (String), `telegram_chat_id` (Integer),
  `image`, `active`, `port` (default 9093).

### Grafana (`docker.io/grafana/grafana`, 12.x line)

- Port `127.0.0.1:3000`.
- Data: `/var/lib/grafana` (UID/GID 472).
- Datasource provisioning file
  `/etc/grafana/provisioning/datasources/prometheus.yaml` on the host,
  mounted read-only to the same container path (only the `datasources`
  subdirectory is mounted so the image's other provisioning dirs remain
  intact), pointing at `http://prometheus:9090` as the default datasource.
- Admin credentials unmanaged (Grafana default first-login flow; UI is
  localhost-only). Dashboards live in the data volume, not in Puppet.
- Class params: `image`, `active`, `port` (default 3000).

### Config-change behavior

Consistent with headscale: config files are `require`d by the container
resources, so a config change does **not** restart a running container.
After a Puppet apply that changed configs, restart the affected service
manually (`systemctl restart <name>.service` on the node). No notify
mechanism is introduced.

## Alert rules (`/etc/prometheus/alerts.yml`, static file)

| Rule                   | Expression (essence)                         | For |
| ---------------------- | -------------------------------------------- | --- |
| `TargetDown`           | `up == 0`                                    | 5m  |
| `FilesystemAlmostFull` | real (non-tmpfs) filesystems < 10% available | 15m |
| `MemoryPressure`       | available memory < 10% of total              | 10m |
| `CpuHigh`              | CPU utilisation > 90%                        | 15m |

Deliberately minimal; thresholds get tuned with real data later.

## Hiera (`data/nodes/z03.de.yaml`)

```yaml
classes:
  - podman_quadlet
  - podman_quadlet::container::headscale
  - podman_quadlet::container::prometheus
  - podman_quadlet::container::alertmanager
  - podman_quadlet::container::grafana

podman_quadlet::container::alertmanager::telegram_bot_token: '<token>'
podman_quadlet::container::alertmanager::telegram_chat_id: <chat-id>
```

Moving the stack to z02 later = moving these five lines (plus optionally
copying `/var/lib/{prometheus,grafana,alertmanager}` for history).

## Testing

rspec-puppet specs for all four new classes on Debian 12 + 13, matching the
repo's full-coverage convention (`spec/classes/podman_quadlet/...`):

- quadlet resources present with expected names,
- ports published on `127.0.0.1` only,
- rendered configs contain the right wiring (datasource URL, alertmanager
  target, telegram receiver, scrape jobs),
- network wrapper declares the `observability` network with the fixed
  subnet.

## Rollout

1. `mise run ci`
2. `bundle exec bolt plan run zezav_bolt::install -t z03 noop=true` — review
   the diff
3. Real apply
4. Verify via SSH tunnel: all four targets `up` in Prometheus
   (`localhost:9090/targets`), Prometheus datasource healthy in Grafana
5. `amtool alert add ...` (or a temporary firing rule) to confirm Telegram
   delivery end-to-end

## Out of scope (explicitly)

- Scraping z01/z02 (needs Tailscale or firewall work — see TODO.md)
- Reverse proxy / public exposure / auth for the UIs
- hiera-eyaml secret encryption (existing TODO, migrate token then)
- Dashboard provisioning via Puppet
- firewalld rules (unmanaged repo-wide at present)
