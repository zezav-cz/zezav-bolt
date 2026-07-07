# Observability Stack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run Prometheus, Grafana, and Alertmanager as podman quadlet containers on z03.de, localhost-only, with Telegram alerting.

**Architecture:** Three new `podman_quadlet::container::*` classes (headscale/minecraft pattern) plus a `podman_quadlet::network::observability` wrapper class that each container class `include`s. Containers share the `observability` podman network (fixed subnet `10.90.0.0/24`) and reach each other by DNS name; Prometheus scrapes the host's node_exporter at the gateway `10.90.0.1:9100`. All host ports bind to `127.0.0.1` via the existing `podman_quadlet::container` define. Classification via the hiera `classes` array in `data/nodes/z03.de.yaml`.

**Tech Stack:** Puppet 8 (openvox via Bolt), rspec-puppet, podman quadlets (`southalc/quadlets` module), Prometheus v3.13.0 (LTS), Alertmanager v0.33.0, Grafana 13.1.0.

**Spec:** `docs/superpowers/specs/2026-07-07-observability-stack-design.md`. Two deliberate refinements vs. the spec text: (1) image versions resolved to the current stable releases listed above (the spec said "verified at implementation time"; its "0.28.x"/"12.x" guesses are outdated); (2) fully static configs (prometheus.yml, alerts.yml, Grafana datasource) live in `files/` and are inlined with the `file()` function instead of parameterless EPP templates — only `alertmanager.yml` (which interpolates the Telegram params) is EPP.

## Global Constraints

- The working tree contains unrelated uncommitted changes. In every commit step, `git add` ONLY the files listed in that task. Never `git add -A` or `git add .`.
- All host port publishing goes through the define's `ports` param (enforces `127.0.0.1`). Never use `public_ports`.
- Image pins (exact, no `latest`): `docker.io/prom/prometheus:v3.13.0`, `docker.io/prom/alertmanager:v0.33.0`, `docker.io/grafana/grafana:13.1.0`.
- Puppet style: 2-space indent, aligned `=>` arrows within a resource, every class has `@summary` and `@param` docs (puppet-lint runs with `--fail-on-warnings`; see any existing class in `site/podman_quadlet/manifests/` for the style).
- Tests use the `on_debian_os` helper from `spec/spec_helper.rb` (Debian 12 + 13 matrix) and `let(:pre_condition) { 'include podman_quadlet' }`.
- Run tests with `mise run test -- <spec file>` from the repo root. Lefthook runs staged-file linters automatically on `git commit` — if prettier/yamllint/puppet-lint fails the commit, fix and retry; do not bypass hooks.
- Commit messages follow Conventional Commits and end with the trailer: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Container-to-container addresses use container ports (`prometheus:9090`, `alertmanager:9093`, `grafana:3000`) — these never depend on the classes' host `port` params.

---

### Task 1: Observability network wrapper class

**Files:**

- Create: `site/podman_quadlet/manifests/network/observability.pp`
- Test: `spec/classes/podman_quadlet/network/observability_spec.rb`

**Interfaces:**

- Consumes: `podman_quadlet::network` define (`site/podman_quadlet/manifests/network.pp`), which creates `quadlets::quadlet { 'observability.network' }`.
- Produces: class `podman_quadlet::network::observability` — no params. Tasks 2–4 `include` it and reference the network as `observability.network` (quadlet unit reference) and the host gateway as `10.90.0.1`.

- [ ] **Step 1: Write the failing test**

Create `spec/classes/podman_quadlet/network/observability_spec.rb`:

```ruby
require 'spec_helper'

describe 'podman_quadlet::network::observability' do
  let(:pre_condition) { 'include podman_quadlet' }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'declares the observability network with the fixed subnet' do
        is_expected.to contain_podman_quadlet__network('observability')
          .with_subnet('10.90.0.0/24')
          .with_gateway('10.90.0.1')
      end

      it 'renders the expected network entry' do
        entry = catalogue.resource('Quadlets::Quadlet', 'observability.network')[:network_entry]
        expect(entry).to eq(
          'NetworkName' => 'observability',
          'Driver'      => 'bridge',
          'Subnet'      => '10.90.0.0/24',
          'Gateway'     => '10.90.0.1',
        )
      end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mise run test -- spec/classes/podman_quadlet/network/observability_spec.rb`
Expected: FAIL — `Could not find declared class podman_quadlet::network::observability`

- [ ] **Step 3: Write the implementation**

Create `site/podman_quadlet/manifests/network/observability.pp`:

```puppet
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mise run test -- spec/classes/podman_quadlet/network/observability_spec.rb`
Expected: PASS (6 examples, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add site/podman_quadlet/manifests/network/observability.pp spec/classes/podman_quadlet/network/observability_spec.rb
git commit -m "feat(podman_quadlet): add observability network

Fixed subnet so the gateway IP is a stable scrape address for the
host's node_exporter.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Prometheus container class

**Files:**

- Create: `site/podman_quadlet/manifests/container/prometheus.pp`
- Create: `site/podman_quadlet/files/container/prometheus.yml`
- Create: `site/podman_quadlet/files/container/prometheus_alerts.yml`
- Test: `spec/classes/podman_quadlet/container/prometheus_spec.rb`

**Interfaces:**

- Consumes: `podman_quadlet::container` define; `podman_quadlet::network::observability` class (Task 1).
- Produces: class `podman_quadlet::container::prometheus` with params `image` (String, default `'docker.io/prom/prometheus:v3.13.0'`), `active` (Boolean, default `true`), `port` (Integer, default `9090`), `retention` (String, default `'15d'`). Serves the API at `prometheus:9090` on the observability network — Task 4's Grafana datasource points there.

- [ ] **Step 1: Write the failing test**

Create `spec/classes/podman_quadlet/container/prometheus_spec.rb`:

```ruby
require 'spec_helper'

describe 'podman_quadlet::container::prometheus' do
  let(:pre_condition) { 'include podman_quadlet' }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'includes the observability network' do
        is_expected.to contain_class('podman_quadlet::network::observability')
      end

      it 'creates config and state directories' do
        is_expected.to contain_file('/etc/prometheus').with_ensure('directory').with_mode('0755')
        is_expected.to contain_file('/var/lib/prometheus')
          .with_ensure('directory')
          .with_owner('nobody')
          .with_group('nogroup')
          .with_mode('0750')
      end

      it 'renders the prometheus config with all four scrape jobs' do
        is_expected.to contain_file('/etc/prometheus/prometheus.yml')
          .with_mode('0644')
          .with_content(%r{- /etc/prometheus/alerts\.yml})
          .with_content(%r{targets: \['alertmanager:9093'\]})
          .with_content(%r{targets: \['localhost:9090'\]})
          .with_content(%r{targets: \['10\.90\.0\.1:9100'\]})
          .with_content(%r{targets: \['grafana:3000'\]})
          .that_requires('File[/etc/prometheus]')
      end

      it 'ships the starter alert rules' do
        is_expected.to contain_file('/etc/prometheus/alerts.yml')
          .with_mode('0644')
          .with_content(%r{alert: TargetDown})
          .with_content(%r{alert: FilesystemAlmostFull})
          .with_content(%r{alert: MemoryPressure})
          .with_content(%r{alert: CpuHigh})
      end

      describe 'the container quadlet' do
        let(:container_entry) do
          catalogue.resource('Quadlets::Quadlet', 'prometheus.container')[:container_entry]
        end

        it 'runs the pinned image on the observability network' do
          expect(container_entry).to include(
            'ContainerName' => 'prometheus',
            'Image'         => 'docker.io/prom/prometheus:v3.13.0',
            'Network'       => 'observability.network',
          )
        end

        it 'publishes the UI on localhost only' do
          expect(container_entry['PodmanArgs']).to eq(['--publish 127.0.0.1:9090:9090'])
        end

        it 'mounts config read-only and data writable' do
          expect(container_entry['Volume']).to eq(
            [
              '/etc/prometheus:/etc/prometheus:ro',
              '/var/lib/prometheus:/prometheus',
            ],
          )
        end

        it 'passes config path and retention on the command line' do
          expect(container_entry['Exec'])
            .to eq('--config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --storage.tsdb.retention.time=15d')
        end
      end

      context 'with a custom retention' do
        let(:params) { { 'retention' => '90d' } }

        it 'passes it through' do
          entry = catalogue.resource('Quadlets::Quadlet', 'prometheus.container')[:container_entry]
          expect(entry['Exec']).to match(%r{--storage\.tsdb\.retention\.time=90d$})
        end
      end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mise run test -- spec/classes/podman_quadlet/container/prometheus_spec.rb`
Expected: FAIL — `Could not find declared class podman_quadlet::container::prometheus`

- [ ] **Step 3: Write the config files**

Create `site/podman_quadlet/files/container/prometheus.yml`:

```yaml
# Managed by Puppet — podman_quadlet::container::prometheus
global:
  scrape_interval: 30s
  evaluation_interval: 30s

rule_files:
  - /etc/prometheus/alerts.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['localhost:9090']

  # Host node_exporter, reached via the observability network gateway
  - job_name: node
    static_configs:
      - targets: ['10.90.0.1:9100']

  - job_name: alertmanager
    static_configs:
      - targets: ['alertmanager:9093']

  - job_name: grafana
    static_configs:
      - targets: ['grafana:3000']
```

Create `site/podman_quadlet/files/container/prometheus_alerts.yml`:

```yaml
# Managed by Puppet — podman_quadlet::container::prometheus
groups:
  - name: node
    rules:
      - alert: TargetDown
        expr: up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: 'Target {{ $labels.instance }} ({{ $labels.job }}) is down'

      - alert: FilesystemAlmostFull
        expr: >
          node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs"}
          / node_filesystem_size_bytes{fstype!~"tmpfs|ramfs"} < 0.10
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: 'Filesystem {{ $labels.mountpoint }} on {{ $labels.instance }} below 10% free'

      - alert: MemoryPressure
        expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.10
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: 'Available memory on {{ $labels.instance }} below 10%'

      - alert: CpuHigh
        expr: 1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) > 0.90
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: 'CPU on {{ $labels.instance }} above 90% for 15 minutes'
```

- [ ] **Step 4: Write the class**

Create `site/podman_quadlet/manifests/container/prometheus.pp`:

```puppet
# @summary Prometheus server container
#
# Scrapes z03-local targets only: itself, the host's node_exporter (via
# the observability network gateway), Alertmanager, and Grafana. The UI
# is published on 127.0.0.1 only — reach it through an SSH tunnel.
#
# @param image
#   Container image reference
# @param active
#   Whether to start and enable the container service
# @param port
#   Host port (bound to 127.0.0.1) mapped to container port 9090
# @param retention
#   TSDB retention time, passed as --storage.tsdb.retention.time
class podman_quadlet::container::prometheus (
  String  $image     = 'docker.io/prom/prometheus:v3.13.0',
  Boolean $active    = true,
  Integer $port      = 9090,
  String  $retention = '15d',
) {
  include podman_quadlet::network::observability

  file { '/etc/prometheus':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # The prom/prometheus image runs as nobody (65534)
  file { '/var/lib/prometheus':
    ensure => directory,
    owner  => 'nobody',
    group  => 'nogroup',
    mode   => '0750',
  }

  file { '/etc/prometheus/prometheus.yml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => file('podman_quadlet/container/prometheus.yml'),
    require => File['/etc/prometheus'],
  }

  file { '/etc/prometheus/alerts.yml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => file('podman_quadlet/container/prometheus_alerts.yml'),
    require => File['/etc/prometheus'],
  }

  podman_quadlet::container { 'prometheus':
    image              => $image,
    active             => $active,
    ports              => ["${port}:9090"],
    network            => 'observability.network',
    volumes            => [
      '/etc/prometheus:/etc/prometheus:ro',
      '/var/lib/prometheus:/prometheus',
    ],
    container_settings => {
      'Exec' => "--config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --storage.tsdb.retention.time=${retention}",
    },
    unit_settings      => { 'Description' => 'Prometheus monitoring server' },
    require            => [
      Class['podman_quadlet::network::observability'],
      File['/etc/prometheus/prometheus.yml'],
      File['/etc/prometheus/alerts.yml'],
      File['/var/lib/prometheus'],
    ],
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mise run test -- spec/classes/podman_quadlet/container/prometheus_spec.rb`
Expected: PASS (all examples, 0 failures)

- [ ] **Step 6: Commit**

```bash
git add site/podman_quadlet/manifests/container/prometheus.pp \
        site/podman_quadlet/files/container/prometheus.yml \
        site/podman_quadlet/files/container/prometheus_alerts.yml \
        spec/classes/podman_quadlet/container/prometheus_spec.rb
git commit -m "feat(podman_quadlet): add prometheus container

Scrapes z03-local targets (host node_exporter via the network gateway,
alertmanager, grafana, itself) with a small starter rule set. UI on
127.0.0.1:9090 only.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Alertmanager container class with Telegram receiver

**Files:**

- Create: `site/podman_quadlet/manifests/container/alertmanager.pp`
- Create: `site/podman_quadlet/templates/container/alertmanager.yml.epp`
- Test: `spec/classes/podman_quadlet/container/alertmanager_spec.rb`

**Interfaces:**

- Consumes: `podman_quadlet::container` define; `podman_quadlet::network::observability` class (Task 1).
- Produces: class `podman_quadlet::container::alertmanager` with params `telegram_bot_token` (String, required), `telegram_chat_id` (Integer, required), `image` (String, default `'docker.io/prom/alertmanager:v0.33.0'`), `active` (Boolean, default `true`), `port` (Integer, default `9093`). Listens at `alertmanager:9093` on the observability network — Task 2's Prometheus config already points there. Task 5 sets the two Telegram params in hiera.

- [ ] **Step 1: Write the failing test**

Create `spec/classes/podman_quadlet/container/alertmanager_spec.rb`:

```ruby
require 'spec_helper'

describe 'podman_quadlet::container::alertmanager' do
  let(:pre_condition) { 'include podman_quadlet' }
  let(:params) do
    {
      'telegram_bot_token' => '1234567890:TEST-token',
      'telegram_chat_id'   => -100_123_456,
    }
  end

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'includes the observability network' do
        is_expected.to contain_class('podman_quadlet::network::observability')
      end

      it 'creates the state directory for the container user' do
        is_expected.to contain_file('/var/lib/alertmanager')
          .with_ensure('directory')
          .with_owner('nobody')
          .with_group('nogroup')
          .with_mode('0750')
      end

      it 'renders the config readable only by the container user' do
        is_expected.to contain_file('/etc/alertmanager/alertmanager.yml')
          .with_owner('nobody')
          .with_group('nogroup')
          .with_mode('0600')
          .with_content(%r{receiver: telegram})
          .with_content(%r{group_by: \['alertname'\]})
          .with_content(%r{repeat_interval: 4h})
          .with_content(%r{bot_token: '1234567890:TEST-token'})
          .with_content(%r{chat_id: -100123456})
          .that_requires('File[/etc/alertmanager]')
      end

      describe 'the container quadlet' do
        let(:container_entry) do
          catalogue.resource('Quadlets::Quadlet', 'alertmanager.container')[:container_entry]
        end

        it 'runs the pinned image on the observability network' do
          expect(container_entry).to include(
            'ContainerName' => 'alertmanager',
            'Image'         => 'docker.io/prom/alertmanager:v0.33.0',
            'Network'       => 'observability.network',
          )
        end

        it 'publishes the UI on localhost only' do
          expect(container_entry['PodmanArgs']).to eq(['--publish 127.0.0.1:9093:9093'])
        end

        it 'mounts config read-only and data writable' do
          expect(container_entry['Volume']).to eq(
            [
              '/etc/alertmanager:/etc/alertmanager:ro',
              '/var/lib/alertmanager:/alertmanager',
            ],
          )
        end
      end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mise run test -- spec/classes/podman_quadlet/container/alertmanager_spec.rb`
Expected: FAIL — `Could not find declared class podman_quadlet::container::alertmanager`

- [ ] **Step 3: Write the template**

Create `site/podman_quadlet/templates/container/alertmanager.yml.epp`:

```
<%- | String  $telegram_bot_token,
      Integer $telegram_chat_id,
| -%>
# Managed by Puppet — podman_quadlet::container::alertmanager
route:
  receiver: telegram
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

receivers:
  - name: telegram
    telegram_configs:
      - bot_token: '<%= $telegram_bot_token %>'
        chat_id: <%= $telegram_chat_id %>
```

- [ ] **Step 4: Write the class**

Create `site/podman_quadlet/manifests/container/alertmanager.pp`:

```puppet
# @summary Alertmanager container with a Telegram receiver
#
# Receives alerts from Prometheus over the observability network and
# forwards them to a Telegram chat. The UI is published on 127.0.0.1
# only — reach it through an SSH tunnel. The bot token lives in
# per-node hiera (plaintext for now — see the secrets TODO).
#
# @param telegram_bot_token
#   Telegram bot API token used to send notifications
# @param telegram_chat_id
#   Telegram chat ID to notify (negative for group chats)
# @param image
#   Container image reference
# @param active
#   Whether to start and enable the container service
# @param port
#   Host port (bound to 127.0.0.1) mapped to container port 9093
class podman_quadlet::container::alertmanager (
  String  $telegram_bot_token,
  Integer $telegram_chat_id,
  String  $image  = 'docker.io/prom/alertmanager:v0.33.0',
  Boolean $active = true,
  Integer $port   = 9093,
) {
  include podman_quadlet::network::observability

  file { '/etc/alertmanager':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # The prom/alertmanager image runs as nobody (65534); the config embeds
  # the bot token, so only that user may read it
  file { '/var/lib/alertmanager':
    ensure => directory,
    owner  => 'nobody',
    group  => 'nogroup',
    mode   => '0750',
  }

  file { '/etc/alertmanager/alertmanager.yml':
    ensure  => file,
    owner   => 'nobody',
    group   => 'nogroup',
    mode    => '0600',
    content => epp('podman_quadlet/container/alertmanager.yml.epp', {
        'telegram_bot_token' => $telegram_bot_token,
        'telegram_chat_id'   => $telegram_chat_id,
    }),
    require => File['/etc/alertmanager'],
  }

  podman_quadlet::container { 'alertmanager':
    image         => $image,
    active        => $active,
    ports         => ["${port}:9093"],
    network       => 'observability.network',
    volumes       => [
      '/etc/alertmanager:/etc/alertmanager:ro',
      '/var/lib/alertmanager:/alertmanager',
    ],
    unit_settings => { 'Description' => 'Prometheus Alertmanager' },
    require       => [
      Class['podman_quadlet::network::observability'],
      File['/etc/alertmanager/alertmanager.yml'],
      File['/var/lib/alertmanager'],
    ],
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mise run test -- spec/classes/podman_quadlet/container/alertmanager_spec.rb`
Expected: PASS (all examples, 0 failures)

- [ ] **Step 6: Commit**

```bash
git add site/podman_quadlet/manifests/container/alertmanager.pp \
        site/podman_quadlet/templates/container/alertmanager.yml.epp \
        spec/classes/podman_quadlet/container/alertmanager_spec.rb
git commit -m "feat(podman_quadlet): add alertmanager container with telegram receiver

Single route to one telegram receiver; bot token comes from per-node
hiera. UI on 127.0.0.1:9093 only.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Grafana container class

**Files:**

- Create: `site/podman_quadlet/manifests/container/grafana.pp`
- Create: `site/podman_quadlet/files/container/grafana_datasource_prometheus.yaml`
- Test: `spec/classes/podman_quadlet/container/grafana_spec.rb`

**Interfaces:**

- Consumes: `podman_quadlet::container` define; `podman_quadlet::network::observability` class (Task 1); Prometheus API at `http://prometheus:9090` (Task 2).
- Produces: class `podman_quadlet::container::grafana` with params `image` (String, default `'docker.io/grafana/grafana:13.1.0'`), `active` (Boolean, default `true`), `port` (Integer, default `3000`).

- [ ] **Step 1: Write the failing test**

Create `spec/classes/podman_quadlet/container/grafana_spec.rb`:

```ruby
require 'spec_helper'

describe 'podman_quadlet::container::grafana' do
  let(:pre_condition) { 'include podman_quadlet' }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'includes the observability network' do
        is_expected.to contain_class('podman_quadlet::network::observability')
      end

      it 'creates the state directory for the grafana user (472)' do
        is_expected.to contain_file('/var/lib/grafana')
          .with_ensure('directory')
          .with_owner('472')
          .with_group('472')
          .with_mode('0750')
      end

      it 'provisions the prometheus datasource' do
        is_expected.to contain_file('/etc/grafana/provisioning/datasources/prometheus.yaml')
          .with_mode('0644')
          .with_content(%r{type: prometheus})
          .with_content(%r{url: http://prometheus:9090})
          .with_content(%r{isDefault: true})
          .that_requires('File[/etc/grafana/provisioning/datasources]')
      end

      describe 'the container quadlet' do
        let(:container_entry) do
          catalogue.resource('Quadlets::Quadlet', 'grafana.container')[:container_entry]
        end

        it 'runs the pinned image on the observability network' do
          expect(container_entry).to include(
            'ContainerName' => 'grafana',
            'Image'         => 'docker.io/grafana/grafana:13.1.0',
            'Network'       => 'observability.network',
          )
        end

        it 'publishes the UI on localhost only' do
          expect(container_entry['PodmanArgs']).to eq(['--publish 127.0.0.1:3000:3000'])
        end

        it 'mounts only the datasources provisioning dir read-only, data writable' do
          expect(container_entry['Volume']).to eq(
            [
              '/etc/grafana/provisioning/datasources:/etc/grafana/provisioning/datasources:ro',
              '/var/lib/grafana:/var/lib/grafana',
            ],
          )
        end
      end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mise run test -- spec/classes/podman_quadlet/container/grafana_spec.rb`
Expected: FAIL — `Could not find declared class podman_quadlet::container::grafana`

- [ ] **Step 3: Write the datasource file**

Create `site/podman_quadlet/files/container/grafana_datasource_prometheus.yaml`:

```yaml
# Managed by Puppet — podman_quadlet::container::grafana
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
```

- [ ] **Step 4: Write the class**

Create `site/podman_quadlet/manifests/container/grafana.pp`:

```puppet
# @summary Grafana container with a provisioned Prometheus datasource
#
# Only the datasources provisioning subdirectory is mounted so the
# image's other provisioning dirs stay intact. Dashboards and admin
# credentials live in the data volume (Grafana default first-login
# flow) — the UI is published on 127.0.0.1 only, reach it through an
# SSH tunnel.
#
# @param image
#   Container image reference
# @param active
#   Whether to start and enable the container service
# @param port
#   Host port (bound to 127.0.0.1) mapped to container port 3000
class podman_quadlet::container::grafana (
  String  $image  = 'docker.io/grafana/grafana:13.1.0',
  Boolean $active = true,
  Integer $port   = 3000,
) {
  include podman_quadlet::network::observability

  file { ['/etc/grafana', '/etc/grafana/provisioning', '/etc/grafana/provisioning/datasources']:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # The grafana image runs as uid/gid 472 (no matching host user)
  file { '/var/lib/grafana':
    ensure => directory,
    owner  => '472',
    group  => '472',
    mode   => '0750',
  }

  file { '/etc/grafana/provisioning/datasources/prometheus.yaml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => file('podman_quadlet/container/grafana_datasource_prometheus.yaml'),
    require => File['/etc/grafana/provisioning/datasources'],
  }

  podman_quadlet::container { 'grafana':
    image         => $image,
    active        => $active,
    ports         => ["${port}:3000"],
    network       => 'observability.network',
    volumes       => [
      '/etc/grafana/provisioning/datasources:/etc/grafana/provisioning/datasources:ro',
      '/var/lib/grafana:/var/lib/grafana',
    ],
    unit_settings => { 'Description' => 'Grafana' },
    require       => [
      Class['podman_quadlet::network::observability'],
      File['/etc/grafana/provisioning/datasources/prometheus.yaml'],
      File['/var/lib/grafana'],
    ],
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mise run test -- spec/classes/podman_quadlet/container/grafana_spec.rb`
Expected: PASS (all examples, 0 failures)

- [ ] **Step 6: Commit**

```bash
git add site/podman_quadlet/manifests/container/grafana.pp \
        site/podman_quadlet/files/container/grafana_datasource_prometheus.yaml \
        spec/classes/podman_quadlet/container/grafana_spec.rb
git commit -m "feat(podman_quadlet): add grafana container

Prometheus datasource provisioned from a file; dashboards and admin
credentials stay in the data volume. UI on 127.0.0.1:3000 only.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Classify the stack on z03 and update docs

**Files:**

- Modify: `data/nodes/z03.de.yaml`
- Modify: `CLAUDE.md` (site-modules list, `podman_quadlet` bullet)

**Interfaces:**

- Consumes: the three container classes (Tasks 2–4) and Alertmanager's `telegram_bot_token` / `telegram_chat_id` params (Task 3).
- Produces: z03 catalog includes the whole stack. The Telegram values are committed as obvious placeholders — the user swaps in real ones before deploying (plaintext hiera is a deliberate, spec'd decision).

- [ ] **Step 1: Update the node hiera**

Replace the full contents of `data/nodes/z03.de.yaml` with (existing headscale keys unchanged, three classes and two keys added):

```yaml
---
classes:
  - podman_quadlet
  - podman_quadlet::container::headscale
  - podman_quadlet::container::prometheus
  - podman_quadlet::container::alertmanager
  - podman_quadlet::container::grafana

podman_quadlet::container::headscale::server_url: 'https://vpn.zezav.cz'
podman_quadlet::container::headscale::acme_email: 'trojakjan24@gmail.com'
podman_quadlet::container::headscale::tls_hostname: 'vpn.zezav.cz'
podman_quadlet::container::headscale::base_domain: 'zezav.lan'
podman_quadlet::container::headscale::oidc_issuer: 'https://zezav-tswrmf.eu1.zitadel.cloud'
podman_quadlet::container::headscale::oidc_client_id: '371339222612804800'

# Placeholders — replace with real values before deploying (plaintext by
# design for now; migrates with the secrets-management TODO)
podman_quadlet::container::alertmanager::telegram_bot_token: 'CHANGEME'
podman_quadlet::container::alertmanager::telegram_chat_id: 0
```

- [ ] **Step 2: Update CLAUDE.md**

In `CLAUDE.md`, change the line:

```
- **podman_quadlet/** — Systemd quadlet containers (headscale, minecraft) with podman networks
```

to:

```
- **podman_quadlet/** — Systemd quadlet containers (headscale, minecraft; prometheus/grafana/alertmanager observability stack on z03, localhost-only) with podman networks
```

- [ ] **Step 3: Run the full test suite and linters**

Run: `mise run ci`
Expected: fmt + lint + all rspec examples pass. If yamllint complains about `data/nodes/z03.de.yaml`, fix the formatting (2-space indent, single quotes) and re-run.

- [ ] **Step 4: Commit**

```bash
git add data/nodes/z03.de.yaml CLAUDE.md
git commit -m "feat(z03): classify observability stack

Prometheus, Grafana, and Alertmanager quadlets on z03; telegram
credentials are placeholders until deployment.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Post-implementation (manual, user-driven — not part of task execution)

1. Put the real Telegram bot token and chat ID into `data/nodes/z03.de.yaml`.
2. `bundle exec bolt plan run zezav_bolt::install -t z03 noop=true` — review the diff.
3. Real apply: `bundle exec bolt plan run zezav_bolt::install -t z03`.
4. Verify: `ssh -L 9090:localhost:9090 -L 3000:localhost:3000 -L 9093:localhost:9093 root@z03.de.zezav.cz`, then check `http://localhost:9090/targets` (4 targets `up`), Grafana datasource health, and send a test alert (`podman exec alertmanager amtool alert add test_alert --alertmanager.url=http://localhost:9093` or a temporary always-firing rule) to confirm Telegram delivery.
5. Config-change reminder: Puppet does not restart containers on config changes — `systemctl restart prometheus.service` (or alertmanager/grafana) after config-only applies.
