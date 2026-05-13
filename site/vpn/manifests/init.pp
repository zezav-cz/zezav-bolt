# Opens firewall ports for VPN admin UI (HTTP, HTTPS, and custom port 4443).
#
# @param ports
#   Array of port hashes to open. Each hash has 'port', 'protocol', and 'label' keys
class vpn (
  Array[Hash] $ports = [
    { 'port' => '4443', 'protocol' => 'tcp', 'label' => 'VPN UI' },
  ],
) {
  firewalld_service { 'Allow HTTP (vpn)':
    ensure  => 'present',
    zone    => $profile::server_firewall::public_zone,
    service => 'http',
  }

  firewalld_service { 'Allow HTTPS (vpn)':
    ensure  => 'present',
    zone    => $profile::server_firewall::public_zone,
    service => 'https',
  }

  $ports.each |$rule| {
    # firewalld service names can't contain spaces
    $slug     = downcase(regsubst($rule['label'], '[^A-Za-z0-9]+', '-', 'G'))
    $svc_name = "vpn-${slug}-${rule['port']}"

    firewalld_custom_service { $svc_name:
      ensure      => present,
      short       => $rule['label'],
      description => "${rule['label']} on port ${rule['port']}",
      ports       => [{ 'port' => $rule['port'], 'protocol' => $rule['protocol'] }],
    }
    -> firewalld_service { "vpn-${rule['port']}":
      ensure  => 'present',
      zone    => $profile::server_firewall::public_zone,
      service => $svc_name,
    }
  }
}
