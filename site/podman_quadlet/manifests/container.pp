# @summary Creates a podman container as a systemd quadlet with security enforcement
#
# Enforces localhost-only port binding by default. Private ports bind to
# 127.0.0.1, so podman's DNAT does not match external traffic. Public ports
# bind to 0.0.0.0 and rely on firewalld's default DNAT-accept behavior.
#
# @param image
#   Container image reference (e.g. 'docker.io/grafana/grafana:11.5.2')
# @param ports
#   Private ports bound to 127.0.0.1 only. Format: 'hostport:containerport' or
#   'hostport:containerport/proto'. Any bind address prefix is stripped and
#   replaced with 127.0.0.1.
# @param public_ports
#   Ports exposed to the public. Each entry is a hash with keys:
#   port (host), container_port, protocol (default tcp), bind_addr (default 0.0.0.0).
#   Set bind_addr to the server's external IP to prevent netavark from creating a
#   catch-all DNAT rule that would hairpin the container's own outbound connections.
# @param volumes
#   Volume mounts. Format: 'name:/path:opts' (e.g. 'mydata:/data:Z')
# @param network
#   Podman network name to attach the container to
# @param environment
#   Environment variables as key-value pairs
# @param capabilities
#   Linux capabilities to add (e.g. ['NET_ADMIN'])
# @param container_settings
#   Additional Container section settings merged into the quadlet.
#   Do not include PublishPort, Volume, Network, or Image here.
# @param active
#   Whether to start and enable the container service
# @param unit_settings
#   Additional Unit section settings
# @param service_settings
#   Additional Service section settings
define podman_quadlet::container (
  String                     $image,
  Boolean                    $active             = true,
  Array[String]              $ports              = [],
  Array[Hash]                $public_ports       = [],
  Array[String]              $volumes            = [],
  Optional[String]           $network            = undef,
  Hash[String, String]       $environment        = {},
  Array[String]              $capabilities       = [],
  Hash                       $container_settings = {},
  Hash                       $unit_settings      = {},
  Hash                       $service_settings   = {},
) {
  # Enforce 127.0.0.1 binding for private ports via PodmanArgs
  # (PublishPort in quadlet files doesn't support IP binding on older podman)
  $private_port_args = $ports.map |$port| {
    $clean = regsubst($port, '^\d+\.\d+\.\d+\.\d+:', '')
    "--publish 127.0.0.1:${clean}"
  }

  # Public ports — bind_addr defaults to 0.0.0.0 but can be a specific IP
  $public_port_args = $public_ports.map |$pp| {
    $proto = pick($pp['protocol'], 'tcp')
    $addr  = pick($pp['bind_addr'], '0.0.0.0')
    "--publish ${addr}:${pp['port']}:${pp['container_port']}/${proto}"
  }

  $all_port_args = $private_port_args + $public_port_args

  # Build Container section
  $entry_base = { 'ContainerName' => $name, 'Image' => $image }

  $entry_ports = $all_port_args.empty ? {
    true  => {},
    false => { 'PodmanArgs' => $all_port_args },
  }

  $entry_volumes = $volumes.empty ? {
    true  => {},
    false => { 'Volume' => $volumes },
  }

  $entry_network = $network ? {
    undef   => {},
    default => { 'Network' => $network },
  }

  $entry_env = $environment.empty ? {
    true  => {},
    false => { 'Environment' => $environment.map |$k, $v| { "${k}=${v}" } },
  }

  $entry_caps = $capabilities.empty ? {
    true  => {},
    false => { 'AddCapability' => $capabilities },
  }

  $merged_container = $entry_base + $entry_ports + $entry_volumes + $entry_network + $entry_env + $entry_caps + $container_settings

  quadlets::quadlet { "${name}.container":
    ensure           => present,
    active           => $active,
    validate_quadlet => false,
    mode             => '0444',
    unit_entry       => { 'Description' => "Podman container: ${name}" } + $unit_settings,
    service_entry    => { 'Restart' => 'always' } + $service_settings,
    install_entry    => { 'WantedBy' => 'default.target' },
    container_entry  => $merged_container,
    require          => Class['podman_quadlet'],
  }
}
