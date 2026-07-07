# @summary Manages the blog.zezav.cz website.
#
# TLS is enabled only once the certificate exists (letsencrypt_directory
# fact): a fresh node converges in two applies — the first serves HTTP and
# issues the certificate, the second turns SSL on.
class web::blog_zezav_cz {
  $_server = 'blog.zezav.cz'

  $_le_cert = $facts.dig('letsencrypt_directory', $_server)
  $_ssl     = $_le_cert =~ NotUndef

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

    ssl                  => $_ssl,
    ssl_cert             => $_ssl ? { true => "${_le_cert}/fullchain.pem", default => undef },
    ssl_key              => $_ssl ? { true => "${_le_cert}/privkey.pem", default => undef },
    ssl_redirect         => $_ssl,
    access_log           => "/var/log/nginx/${_server}.access.log",
    error_log            => "/var/log/nginx/${_server}.error.log",
    use_default_location => false,
  }

  # Location
  nginx::resource::location { "${_server}/":
    ensure      => present,
    server      => $_server,
    location    => '/',
    ssl         => $_ssl,
    ssl_only    => $_ssl,
    try_files   => ['$uri', '$uri/', '=404'],
    index_files => ['index.html'],
  }

  # TLS certificate — the nginx authenticator needs a running nginx
  include profile::certbot

  letsencrypt::certonly { $_server:
    ensure  => present,
    domains => [$_server],
    plugin  => 'nginx',
    require => Class['nginx::service'],
  }
}
