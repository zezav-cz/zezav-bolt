# @summary Creates a podman volume as a systemd quadlet
#
# @param mode
#   File mode for the quadlet file
define podman_quadlet::volume (
  String $mode = '0444',
) {
  quadlets::quadlet { "${name}.volume":
    ensure           => present,
    validate_quadlet => false,
    mode             => $mode,
    volume_entry     => { 'VolumeName' => $name },
    install_entry    => { 'WantedBy' => 'default.target' },
    require          => Class['podman_quadlet'],
  }
}
