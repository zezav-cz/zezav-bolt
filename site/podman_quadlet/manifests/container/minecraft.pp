# @summary Minecraft server container (itzg/minecraft-server)
#
# Runs a Minecraft Java edition server as a podman quadlet. The port is bound
# on localhost and optionally on the Tailscale IP so the server is reachable
# only within the VPN — no public firewall rule needed.
#
# @param image
#   Container image reference
# @param tailscale_ip
#   If set, additionally binds the port to this IP (the node's Tailscale IP)
# @param port
#   Minecraft TCP port (host and container)
# @param base_dir
#   Host path for data storage
# @param memory
#   JVM heap size passed to the server (e.g. '3G')
# @param environment
#   Extra or override environment variables merged on top of the defaults
class podman_quadlet::container::minecraft (
  String               $image        = 'docker.io/itzg/minecraft-server:latest',
  Optional[String]     $tailscale_ip = undef,
  Integer              $port         = 25565,
  String[1]            $base_dir     = '/var/mc',
  String[1]            $memory       = '3G',
  Hash[String, String] $environment  = {},
) {
  $extra_ports = $tailscale_ip ? {
    undef   => [],
    default => ["--publish ${tailscale_ip}:${port}:${port}"],
  }

  $default_env = {
    'EULA'            => 'TRUE',
    'MEMORY'          => $memory,
    'LOG_TIMESTAMP'   => 'true',
    'DIFFICULTY'      => 'normal',
    'FORCE_GAMEMODE'  => 'false',
    'SNOOPER_ENABLED' => 'false',
    'MODE'            => 'survival',
    'ONLINE_MODE'     => 'false',
  }

  $data_dir = "${base_dir}/data"
  file { [$base_dir, $data_dir]:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0750',
    recurse => true,
  }

  podman_quadlet::container { 'mc':
    image              => $image,
    volumes            => ["${data_dir}:/data:Z"],
    environment        => $default_env + $environment,
    container_settings => {
      'PodmanArgs' => ["--publish 127.0.0.1:${port}:${port}"] + $extra_ports,
    },
    unit_settings      => { 'Description' => 'Minecraft Server (itzg)' },
    require            => File[$data_dir],
  }
}
