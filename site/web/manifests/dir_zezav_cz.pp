# Manages the dir.zezav.cz directory listing site with JSON API support.
class web::dir_zezav_cz {
  $_server = 'dir.zezav.cz'

  # Document root
  file { "/var/www/uploader/${_server}":
    ensure => 'directory',
    owner  => 'uploader',
    group  => 'uploader',
    mode   => '0755',
  }

  # Nginx server
  nginx::resource::server { $_server:
    ensure               => present,
    server_name          => [$_server],
    www_root             => "/var/www/uploader/${_server}",
    index_files          => [],
    ssl                  => true,
    ssl_cert             => "/etc/letsencrypt/live/${_server}/fullchain.pem",
    ssl_key              => "/etc/letsencrypt/live/${_server}/privkey.pem",
    ssl_redirect         => false,
    access_log           => "/var/log/nginx/${_server}.access.log",
    error_log            => "/var/log/nginx/${_server}.error.log",
    use_default_location => false,
  }

  # Locations — HTML autoindex with JSON API via Accept header
  nginx::resource::location { "${_server}/":
    ensure               => present,
    server               => $_server,
    ssl                  => true,
    ssl_only             => false,

    location             => '/',

    autoindex            => 'on',
    autoindex_exact_size => 'off',
    autoindex_localtime  => 'on',
    index_files          => [],

    raw_prepend          => '
      if ($http_accept ~* "application/json") {
        rewrite ^/(.*)$ /_json_output/$1 last;
      }
    ',

    require              => Nginx::Resource::Server[$_server],
  }

  nginx::resource::location { "${_server}/_json_output":
    ensure               => present,
    server               => $_server,
    ssl                  => true,
    ssl_only             => false,

    location             => '/_json_output/',

    internal             => true,
    autoindex            => 'on',
    autoindex_exact_size => 'on',
    autoindex_localtime  => 'on',
    autoindex_format     => 'json',
    location_cfg_append  => {
      alias                => '/var/www/uploader/dir.zezav.cz/',
    },
    index_files          => [],

    require              => Nginx::Resource::Server[$_server],
  }

  # TLS certificate
  include profile::certbot

  letsencrypt::certonly { $_server:
    ensure  => present,
    domains => [$_server],
    plugin  => 'nginx',
  }
}
