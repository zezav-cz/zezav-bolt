# Manages podman quadlet configuration and user
#
# @param user
#   The system user account under which podman quadlets will run
class podman_quadlet (
  String $user = lookup('podman_quadlet::defaults::user')
) {
  class { 'quadlets':
    manage_autoupdate_timer  => false,
    create_quadlet_dir       => true,
    create_quadlet_users_dir => true,
    purge_quadlet_dir        => true,
  }

  # Do i need such home dir?
  $_home_dir = "/home/system/${user}"
  accounts::user { $user:
    ensure     => present,
    home       => $_home_dir,
    managehome => true,
    shell      => '/usr/sbin/nologin',
    system     => true,
    comment    => 'User for running podman quadlets',
    managevim  => false,
    membership => 'inclusive',
    require    => Class['accounts'],
  }
  -> quadlets::user { $user:
    manage_user => false,
    homedir     => $_home_dir,
  }
}
