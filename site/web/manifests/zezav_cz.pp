# Manages the zezav.cz website with www-to-apex redirect.
class web::zezav_cz {
  $_server     = 'zezav.cz'
  $_www_server = "www.${_server}"

  # Document root
  file { "/var/www/uploader/${_server}":
    ensure => 'directory',
    owner  => 'uploader',
    group  => 'uploader',
    mode   => '0755',
  }

  # Nginx servers
  nginx::resource::server { $_www_server:
    ensure               => present,
    server_name          => [$_www_server],
    index_files          => [],
    ssl                  => true,
    ssl_cert             => "/etc/letsencrypt/live/${_server}/fullchain.pem",
    ssl_key              => "/etc/letsencrypt/live/${_server}/privkey.pem",
    access_log           => "/var/log/nginx/${_server}.access.log",
    error_log            => "/var/log/nginx/${_server}.error.log",
    use_default_location => false,
  }

  nginx::resource::server { $_server:
    ensure               => present,
    server_name          => [$_server],
    www_root             => "/var/www/uploader/${_server}",
    listen_options       => 'default_server',
    index_files          => [],
    ssl                  => true,
    ssl_cert             => "/etc/letsencrypt/live/${_server}/fullchain.pem",
    ssl_key              => "/etc/letsencrypt/live/${_server}/privkey.pem",
    ssl_redirect         => true,
    access_log           => "/var/log/nginx/${_server}.access.log",
    error_log            => "/var/log/nginx/${_server}.error.log",
    use_default_location => false,
  }

  # Locations
  nginx::resource::location { "${_www_server}/":
    ensure      => present,
    server      => $_www_server,
    ssl         => true,
    location    => '/',
    raw_append  => ["return 301 https://${_server}\$request_uri;"],
    index_files => [],
  }

  nginx::resource::location { "${_server}/":
    ensure      => present,
    server      => $_server,
    ssl         => true,
    ssl_only    => true,
    location    => '/',
    try_files   => ['$uri', '$uri/', '=404'],
    index_files => ['index.html'],
  }

  # TLS certificate
  include profile::certbot

  letsencrypt::certonly { $_server:
    ensure  => present,
    domains => [$_server, $_www_server],
    plugin  => 'nginx',
  }
}
