# Manages the blog.zezav.cz website.
class web::blog_zezav_cz {
  $_server = 'blog.zezav.cz'

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
    ssl_redirect         => true,
    access_log           => "/var/log/nginx/${_server}.access.log",
    error_log            => "/var/log/nginx/${_server}.error.log",
    use_default_location => false,
  }

  # Location
  nginx::resource::location { "${_server}/":
    ensure      => present,
    server      => $_server,
    location    => '/',
    ssl         => true,
    ssl_only    => true,
    try_files   => ['$uri', '$uri/', '=404'],
    index_files => ['index.html'],
  }

  # TLS certificate
  include profile::certbot

  letsencrypt::certonly { $_server:
    ensure  => present,
    domains => [$_server],
    plugin  => 'nginx',
  }
}
