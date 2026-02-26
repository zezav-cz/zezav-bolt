class podman_quadlet::container::prometheus {
  $_user = lookup('podman_quadlet::defaults::user')
  $_home_dir = "/home/system/${_user}"
  podman::quadlet { 'prometheus':
    ensure           => 'present',
    validate_quadlet => true,
    mode             => '0444',
    active           => true,
    user             => undef,
    group            => undef,
    location         => 'system',

    container_entry  => {
      ContainerName => 'q_prometheus',
      Image         => 'quay.io/prometheus/prometheus:v3.9.1',
    },

    require          => Podman::Package['podman'],
  }
}
