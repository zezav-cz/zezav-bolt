# Manages web server with nginx and firewall rules
#
# @param fw_zone
#   The firewalld zone to apply HTTP/HTTPS rules to. Required if firewall_http or firewall_https is enabled
# @param firewall_https
#   Whether to enable HTTPS (port 443) through the firewall
# @param firewall_http
#   Whether to enable HTTP (port 80) through the firewall
class web (
  Optional[String[1]] $fw_zone        = undef,
  Boolean             $firewall_https = true,
  Boolean             $firewall_http  = true,
) {
  if ($firewall_http or $firewall_https ) and $fw_zone == undef {
    fail('firewall_http or firewall_https is enabled but fw_zone is not set')
  }

  if $firewall_http {
    firewalld_service { 'Allow HTTP':
      ensure  => 'present',
      zone    => $fw_zone,
      service => 'http',
    }
  }

  if $firewall_https {
    firewalld_service { 'Allow HTTPS':
      ensure  => 'present',
      zone    => $fw_zone,
      service => 'https',
    }
  }

  include nginx

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
}
