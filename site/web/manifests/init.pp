# @summary Manages the nginx web server, its sites, and the web roots.
class web {
  # manage_repo => false: nginx must come from the Debian archive — the
  # nginx.org packages cannot load the distro libnginx-mod-http-lua that
  # profile::nginx_oidc installs (different ABI). Also remove the nginx.org
  # source a previous manage_repo default left behind, so apt upgrades can
  # never pull the incompatible 1.3x build.
  apt::source { 'nginx':
    ensure => absent,
  }

  class { 'nginx':
    manage_repo     => false,
    confd_purge     => true,
    server_purge    => true,
    http_cfg_append => {
      'lua_package_path'            => '"/etc/nginx/lua/?.lua;;"',
      'lua_ssl_trusted_certificate' => '/etc/ssl/certs/ca-certificates.crt',
      'lua_ssl_verify_depth'        => '3',
    },
  }

  file { '/var/www':
    ensure => 'directory',
    owner  => 'www-data',
    group  => 'www-data',
    mode   => '0755',
  }

  -> file { '/var/www/uploader':
    ensure => 'directory',
    owner  => 'uploader',
    group  => 'www-data',
    mode   => '0755',
  }

  include web::zezav_cz
  include web::blog_zezav_cz
  include web::dir_zezav_cz
  include web::private_zezav_cz
}
