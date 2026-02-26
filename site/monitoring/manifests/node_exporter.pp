# Manages node_exporter service and systemd unit
#
# @param version
#   The version of node_exporter to install and run
class monitoring::node_exporter (
  String $version = '1.10.2',
) {
  class { 'monitoring::binary::node_exporter':
    version => $version,
  }

  file { '/etc/systemd/system/node_exporter.service':
    ensure  => file,
    content => epp('monitoring/node_exporter.service.epp'),
    notify  => Exec['node_exporter-systemd-reload'],
  }

  exec { 'node_exporter-systemd-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  service { 'node_exporter':
    ensure  => running,
    enable  => true,
    require => [
      File['/etc/systemd/system/node_exporter.service'],
      Class['monitoring::binary::node_exporter'],
    ],
  }
}
