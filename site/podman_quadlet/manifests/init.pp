# @summary Base class for podman quadlet container management
#
# Sets up podman and the quadlets systemd integration. Include this class
# first, then add containers, networks, and volumes via the defined types
# or specific container classes.
#
# @param purge_quadlet_dir
#   Whether to purge unmanaged quadlet files from the systemd directory
class podman_quadlet (
  Boolean $purge_quadlet_dir = true,
) {
  include profile::podman

  class { 'quadlets':
    manage_package           => false,
    manage_service           => false,
    create_quadlet_dir       => true,
    create_quadlet_users_dir => true,
    purge_quadlet_dir        => $purge_quadlet_dir,
  }
}
