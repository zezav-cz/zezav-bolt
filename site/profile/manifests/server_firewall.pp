# Manages server firewall configuration using firewalld
#
# @param default_zone
#   The firewalld default_zone — catch-all for unassigned interfaces (target: BLOCK)
# @param public_zone
#   Zone for the server's public internet-facing interfaces
# @param icmp4_enabled
#   Whether to enable ICMPv4 (ping) traffic
# @param icmp6_enabled
#   Whether to enable ICMPv6 traffic
# @param headscale_enabled
#   Whether to open HTTP (80), HTTPS (443), and WireGuard UDP 41641 for Headscale
class profile::server_firewall (
  String[1] $default_zone      = 'public',
  String[1] $public_zone       = 'block',
  Boolean   $icmp4_enabled     = true,
  Boolean   $icmp6_enabled     = true,
  Boolean   $headscale_enabled = true,
) {
  # Default zone is public
  class { 'firewalld':
    package_ensure   => 'installed',
    service_ensure   => 'running',
    service_enable   => true,
    default_zone     => $default_zone,
    log_denied       => undef,
    firewall_backend => 'nftables',
  }

  # Derive interface lists from facts — no hardcoded names
  $all_ifaces           = keys($facts['networking']['interfaces'])
  $lo_interfaces        = $all_ifaces.filter |$iface| { $iface =~ /^lo/ }
  $tailscale_interfaces = $all_ifaces.filter |$iface| { $iface =~ /^tailscale/ }
  # $podman_interfaces    = $all_ifaces.filter |$iface| { $iface =~ /^podman/ }
  $public_interfaces    = $all_ifaces.filter |$iface| {
    $iface !~ /^(lo|tailscale|veth|podman|cni|br-|docker|virbr)/
  }

  # purge unused built-in zones
  firewalld_zone { ['drop', 'dmz', 'home', 'work', 'external']:
    ensure     => present,
    interfaces => [],
    sources    => [],
  }

  # Public-facing interfaces — masquerade enables container internet access
  firewalld_zone { 'block':
    ensure     => present,
    masquerade => true,
    interfaces => $public_interfaces,
    sources    => [],
  }

  # Catch-all default zone for any unassigned interface — blocks everything
  firewalld_zone { 'public':
    ensure               => present,
    icmp_block_inversion => false,
    masquerade           => false,
    interfaces           => [],
    sources              => [],
  }

  # Tailscale — internal (trusted peers, less permissive than lo)
  # Sources include the headscale CIDR so the zone applies even if the
  # tailscale0 interface isn't visible in facts during the catalog run.
  firewalld_zone { 'internal':
    ensure     => present,
    target     => 'ACCEPT',
    interfaces => $tailscale_interfaces,
    sources    => ['100.64.0.0/10'],
  }

  # lo — fully trusted (built-in zone, target is ACCEPT by default)
  firewalld_zone { 'trusted':
    ensure     => present,
    interfaces => $lo_interfaces,
    sources    => [],
  }

  # Podman
  # firewalld_zone { 'netavark_zone':
  #   ensure     => present,
  #   target     => 'ACCEPT',
  # }

  # firewalld_policy { 'podman-forward':
  #   ensure => absent,
  # }

  # firewalld_policy { 'podmanToExternal':
  #   ensure           => present,
  #   target           => 'ACCEPT',
  #   priority      => -1000,
  #   ingress_zones    => ['netavark_zone'],
  #   egress_zones     => ['external'],
  #   masquerade    => true,
  # }

  # ---------------
  # Tailscale WireGuard — needed for direct peer connections (without this,
  # Tailscale falls back to DERP relays which still work but add latency)
  firewalld_port { 'Allow Tailscale WireGuard - public':
    ensure   => 'present',
    zone     => $public_zone,
    port     => '41641',
    protocol => 'udp',
  }

  # ---------------
  # SSH

  firewalld_service { 'Allow SSH - public':
    ensure  => 'present',
    zone    => $public_zone,
    service => 'ssh',
  }

  firewalld_service { 'Allow SSH - internal':
    ensure  => 'present',
    zone    => 'internal',
    service => 'ssh',
  }

  firewalld_rich_rule { 'Allow ICMP - internal':
    ensure   => 'present',
    zone     => 'internal',
    protocol => 'icmp',
    action   => 'accept',
  }

  firewalld_service { 'Allow SSH - trusted':
    ensure  => 'present',
    zone    => 'trusted',
    service => 'ssh',
  }

  # # Public internet-facing interfaces — only explicitly allowed traffic
  # firewalld_zone { $public_zone:
  #   ensure               => present,
  #   icmp_block_inversion => false,
  #   icmp_blocks          => [],
  #   interfaces           => $public_interfaces,
  #   masquerade           => false,
  #   purge_rich_rules     => true,
  #   purge_services       => true,
  #   purge_ports          => true,
  #   target               => '%%DROP%%',
  # }

  # # Netavark (podman firewall driver) creates this zone and manages its sources dynamically.
  # # Only masquerade is managed here so containers can initiate outbound connections.
  # firewalld_zone { 'netavark_zone':
  #   ensure           => present,
  #   masquerade       => true,
  #   purge_rich_rules => false,
  #   purge_services   => false,
  #   purge_ports      => false,
  # }

  # # Without this policy, firewalld generates reject rules for forwarded traffic crossing
  # # from netavark_zone to the public zone (eth0), blocking containers from reaching the internet.
  # firewalld_policy { 'podman-forward':
  #   ensure        => present,
  #   priority      => 100,
  #   ingress_zones => ['netavark_zone'],
  #   egress_zones  => [$public_zone],
  #   target        => 'ACCEPT',
  #   masquerade    => true,
  # }

  # if $icmp4_enabled {
  #   firewalld_rich_rule { 'Allow ICMP IPv4':
  #     ensure   => present,
  #     zone     => $public_zone,
  #     protocol => 'icmp',
  #     action   => 'accept',
  #     family   => 'ipv4',
  #   }
  # }

  # if $icmp6_enabled {
  #   firewalld_rich_rule { 'Allow ICMP IPv6':
  #     ensure   => present,
  #     zone     => $public_zone,
  #     protocol => 'ipv6-icmp',
  #     action   => 'accept',
  #     family   => 'ipv6',
  #   }
  # }

  # firewalld_service { 'Allow SSH':
  #   ensure  => 'present',
  #   zone    => $public_zone,
  #   service => 'ssh',
  # }
}
