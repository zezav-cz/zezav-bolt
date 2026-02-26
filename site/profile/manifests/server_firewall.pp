# Manages server firewall configuration using firewalld
#
# @param default_zone
#   The default firewalld zone to use
# @param icmp4_enabled
#   Whether to enable ICMPv4 (ping) traffic
# @param icmp6_enabled
#   Whether to enable ICMPv6 traffic
class profile::server_firewall (
  String[1] $default_zone  = 'drop',
  Boolean   $icmp4_enabled = true,
  Boolean   $icmp6_enabled = true,
) {
  class { 'firewalld':
    package_ensure   => 'installed',
    service_ensure   => 'running',
    service_enable   => true,
    default_zone     => $default_zone,
    log_denied       => undef,
    firewall_backend => 'nftables',
  }

  firewalld_zone { 'trusted':
    ensure     => present,
    target     => '%%ACCEPT%%',
    interfaces => ['lo'],
  }

  firewalld_zone { $default_zone:
    ensure               => present,
    icmp_block_inversion => false,
    icmp_blocks          => [],
    masquerade           => false,
    purge_rich_rules     => true,
    purge_services       => true,
    purge_ports          => true,
    target               => '%%DROP%%',
  }

  if $icmp4_enabled {
    firewalld_rich_rule { 'Allow ICMP IPv4':
      ensure   => present,
      zone     => $default_zone,
      protocol => 'icmp',
      action   => 'accept',
      family   => 'ipv4',
    }
  }

  if $icmp6_enabled {
    firewalld_rich_rule { 'Allow ICMP IPv6':
      ensure   => present,
      zone     => $default_zone,
      protocol => 'ipv6-icmp',
      action   => 'accept',
      family   => 'ipv6',
    }
  }

  firewalld_service { 'Allow SSH':
    ensure  => 'present',
    zone    => $default_zone,
    service => 'ssh',
  }
}
