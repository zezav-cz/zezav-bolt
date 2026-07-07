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
