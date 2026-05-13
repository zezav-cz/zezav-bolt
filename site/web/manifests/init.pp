# Manages web server with nginx and firewall rules
#
# @param firewall_http
#   Whether to enable HTTP (port 80) through the firewall
# @param firewall_https
#   Whether to enable HTTPS (port 443) through the firewall
class web (
  Boolean $firewall_http  = true,
  Boolean $firewall_https = true,
) {
  if $firewall_http {
    firewalld_service { 'Allow HTTP':
      ensure  => 'present',
      zone    => $profile::server_firewall::public_zone,
      service => 'http',
    }
  }

  if $firewall_https {
    firewalld_service { 'Allow HTTPS':
      ensure  => 'present',
      zone    => $profile::server_firewall::public_zone,
      service => 'https',
    }
  }

  class { 'nginx':
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
