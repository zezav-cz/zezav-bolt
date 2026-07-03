# @summary Headscale control server container
#
# Manages the headscale container and its configuration file.
# The service is active by default — set active => false to keep it stopped.
#
# @param server_url
#   Public URL clients connect to (e.g. 'https://vpn.example.com')
# @param acme_email
#   Email for Let's Encrypt registration
# @param tls_hostname
#   Domain for the Let's Encrypt certificate
# @param base_domain
#   MagicDNS base domain (must differ from the server_url domain)
# @param oidc_issuer
#   OIDC provider issuer URL
# @param oidc_client_id
#   OIDC client ID
# @param fw
#   Whether to manage the firewalld rules for headscale (HTTP/HTTPS, WireGuard, STUN)
# @param image
#   Container image reference
# @param active
#   Whether to start and enable the container service
# @param http_port
#   Host port mapped to container port 80 (ACME HTTP-01 challenge)
# @param https_port
#   Host port mapped to container port 4443 (HTTPS)
class podman_quadlet::container::headscale (
  String  $server_url,
  String  $acme_email,
  String  $tls_hostname,
  String  $base_domain,
  String  $oidc_issuer,
  String  $oidc_client_id,
  Boolean $fw         = true,
  String  $image      = 'docker.io/headscale/headscale:0.28',
  Boolean $active     = true,
  Integer $http_port  = 80,
  Integer $https_port = 443,
) {
  file { '/etc/headscale':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0750',
  }

  file { '/var/lib/headscale':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0750',
  }

  file { '/etc/headscale/config.yaml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => epp('podman_quadlet/container/headscale_config.yaml.epp', {
        'server_url'     => $server_url,
        'acme_email'     => $acme_email,
        'tls_hostname'   => $tls_hostname,
        'base_domain'    => $base_domain,
        'oidc_issuer'    => $oidc_issuer,
        'oidc_client_id' => $oidc_client_id,
    }),
    require => File['/etc/headscale'],
  }
  if ($fw) {
    ['public', 'block', 'drop', 'internal', 'trusted'].each |$zone| {
      firewalld_service { "Allow HTTPS - headscale - ${zone}":
        ensure  => 'present',
        zone    => $zone,
        service => 'https',
      }
      firewalld_service { "Allow HTTP - headscale ACME - ${zone}":
        ensure  => 'present',
        zone    => $zone,
        service => 'http',
      }
    }
    ['public', 'internal', 'block', 'trusted'].each |$zone| {
      firewalld_port { "Allow WireGuard - headscale - ${zone}":
        ensure   => 'present',
        zone     => $zone,
        port     => '41641',
        protocol => 'udp',
      }
    }
    ['public', 'block', 'drop', 'internal', 'trusted'].each |$zone| {
      firewalld_port { "Tailscale STUN - headscale - ${zone}":
        ensure   => 'present',
        zone     => $zone,
        port     => '3478',
        protocol => 'udp',
      }
    }
  }

  podman_quadlet::container { 'headscale':
    image              => $image,
    active             => $active,
    public_ports       => [
      { 'port' => $http_port,  'container_port' => 80,   'protocol' => 'tcp' },
      { 'port' => $https_port, 'container_port' => 4443, 'protocol' => 'tcp', 'bind_addr' => $facts['networking']['ip'] },
      { 'port' => $https_port, 'container_port' => 4443, 'protocol' => 'tcp', 'bind_addr' => '127.0.0.1' },
    ],
    volumes            => [
      '/etc/headscale:/etc/headscale:ro',
      '/var/lib/headscale:/var/lib/headscale',
    ],
    container_settings => {
      'DNS'            => ['1.1.1.1', '9.9.9.9'],
      'Exec'           => 'serve',
      'ReadOnly'       => true,
      'Mount'          => 'type=tmpfs,tmpfs-size=64M,destination=/var/run/headscale',
      'HealthCmd'      => 'headscale health',
      'HealthInterval' => '30s',
      'HealthRetries'  => '3',
    },
    unit_settings      => { 'Description' => 'Headscale - Open source Tailscale control server' },
    require            => [File['/etc/headscale/config.yaml'], File['/var/lib/headscale']],
  }
}
