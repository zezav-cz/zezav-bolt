# @summary Manages the zezav.cz website with www-to-apex redirect.
#
# TLS is enabled only once the certificate exists (letsencrypt_directory
# fact): a fresh node converges in two applies — the first serves HTTP and
# issues the certificate, the second turns SSL on.
class web::zezav_cz {
  $_server     = 'zezav.cz'
  $_www_server = "www.${_server}"

  $_le_cert = $facts.dig('letsencrypt_directory', $_server)
  $_ssl     = $_le_cert =~ NotUndef

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
    ssl                  => $_ssl,
    ssl_cert             => $_ssl ? { true => "${_le_cert}/fullchain.pem", default => undef },
    ssl_key              => $_ssl ? { true => "${_le_cert}/privkey.pem", default => undef },
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
    ssl                  => $_ssl,
    ssl_cert             => $_ssl ? { true => "${_le_cert}/fullchain.pem", default => undef },
    ssl_key              => $_ssl ? { true => "${_le_cert}/privkey.pem", default => undef },
    ssl_redirect         => $_ssl,
    access_log           => "/var/log/nginx/${_server}.access.log",
    error_log            => "/var/log/nginx/${_server}.error.log",
    use_default_location => false,
  }

  # Locations
  nginx::resource::location { "${_www_server}/":
    ensure      => present,
    server      => $_www_server,
    ssl         => $_ssl,
    location    => '/',
    raw_append  => ["return 301 https://${_server}\$request_uri;"],
    index_files => [],
  }

  nginx::resource::location { "${_server}/":
    ensure      => present,
    server      => $_server,
    ssl         => $_ssl,
    ssl_only    => $_ssl,
    location    => '/',
    try_files   => ['$uri', '$uri/', '=404'],
    index_files => ['index.html'],
  }

  # TLS certificate — the nginx authenticator needs a running nginx
  include profile::certbot

  letsencrypt::certonly { $_server:
    ensure  => present,
    domains => [$_server, $_www_server],
    plugin  => 'nginx',
    require => Class['nginx::service'],
  }
}
