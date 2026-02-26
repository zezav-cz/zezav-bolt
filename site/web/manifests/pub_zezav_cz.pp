class web::pub_zezav_cz {
  $_server = 'pub.zezav.cz'
  nginx::resource::server { $_server:
    ensure               => present,
    server_name          => [$_server],
    www_root             => "/var/www/uploader/${_server}",
    index_files          => [],

    # SSL Configuration
    ssl                  => true,
    ssl_cert             => "/etc/letsencrypt/live/${_server}/fullchain.pem",
    ssl_key              => "/etc/letsencrypt/live/${_server}/privkey.pem",
    ssl_redirect         => true, # Redirect HTTP to HTTPS

    # Logging
    access_log           => "/var/log/nginx/${_server}.access.log",
    error_log            => "/var/log/nginx/${_server}.error.log",

    # Custom Locations
    use_default_location => false,
  }

  nginx::resource::location { "${_server}/":
    ensure      => present,
    server      => $_server,
    location    => '/',
    ssl         => true,
    ssl_only    => true,
    try_files   => ['$uri', '$uri/', '=404'],
    index_files => ['index.html'],
  }

  letsencrypt::certonly { $_server:
    ensure  => present,
    domains => [$_server],
    plugin  => 'nginx',
  }
}
