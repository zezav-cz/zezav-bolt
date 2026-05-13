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

  systemd::unit_file { 'node_exporter.service':
    content => epp('monitoring/node_exporter.service.epp'),
    enable  => true,
    active  => true,
    require => Class['monitoring::binary::node_exporter'],
  }
}
