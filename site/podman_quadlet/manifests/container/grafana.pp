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
