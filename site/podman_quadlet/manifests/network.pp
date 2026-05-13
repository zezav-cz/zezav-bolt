# @summary Creates a podman network as a systemd quadlet
#
# @param driver
#   Network driver (bridge or macvlan)
# @param subnet
#   Network subnet (e.g. '10.89.0.0/24')
# @param gateway
#   Network gateway address
# @param ipv6
#   Whether to enable IPv6 on the network
# @param internal
#   Whether the network is internal only (no external routing)
define podman_quadlet::network (
  String           $driver   = 'bridge',
  Optional[String] $subnet   = undef,
  Optional[String] $gateway  = undef,
  Boolean          $ipv6     = false,
  Boolean          $internal = false,
) {
  $entry_base = { 'NetworkName' => $name, 'Driver' => $driver }

  $entry_subnet = $subnet ? {
    undef   => {},
    default => { 'Subnet' => $subnet },
  }

  $entry_gateway = $gateway ? {
    undef   => {},
    default => { 'Gateway' => $gateway },
  }

  $entry_ipv6 = $ipv6 ? {
    true  => { 'IPv6' => 'true' },
    false => {},
  }

  $entry_internal = $internal ? {
    true  => { 'Internal' => 'true' },
    false => {},
  }

  quadlets::quadlet { "${name}.network":
    ensure           => present,
    active           => true,
    validate_quadlet => false,
    mode             => '0444',
    network_entry    => $entry_base + $entry_subnet + $entry_gateway + $entry_ipv6 + $entry_internal,
    install_entry    => { 'WantedBy' => 'default.target' },
    require          => Class['podman_quadlet'],
  }
}
