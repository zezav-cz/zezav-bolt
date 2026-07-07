# @summary Manages the private.zezav.cz website, protected by OIDC via lua-resty-openidc.
#
# TLS is enabled only once the certificate exists (letsencrypt_directory
# fact): a fresh node converges in two applies — the first serves HTTP and
# issues the certificate, the second turns SSL on (OIDC needs the https
# redirect_uri, so the gate is fully functional from the second apply).
#
# @param oidc_discovery_url OIDC provider discovery URL
# @param oidc_client_id     OIDC client ID registered for this site
# @param oidc_session_secret Random secret used to sign session cookies (min 32 chars)
# @param oidc_client_secret OIDC client secret (empty for PKCE apps)
class web::private_zezav_cz (
  String $oidc_discovery_url,
  String $oidc_client_id,
  String $oidc_session_secret,
  String $oidc_client_secret = '',
) {
  $_server = 'private.zezav.cz'

  $_le_cert = $facts.dig('letsencrypt_directory', $_server)
  $_ssl     = $_le_cert =~ NotUndef

  include profile::nginx_oidc

  # Lua config file — loaded at request time via require("oidc_opts")
  file { '/etc/nginx/lua/oidc_opts.lua':
    ensure  => file,
    owner   => 'root',
    group   => 'www-data',
    mode    => '0640',
    content => epp('web/oidc_opts.lua.epp', {
        discovery_url       => $oidc_discovery_url,
        client_id           => $oidc_client_id,
        client_secret       => $oidc_client_secret,
        session_secret      => $oidc_session_secret,
        redirect_uri        => "https://${_server}/redirect_uri",
        logout_redirect_uri => 'https://zezav.cz',
    }),
    require => File['/etc/nginx/lua'],
    notify  => Service['nginx'],
  }

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
    raw_prepend          => ['resolver 1.1.1.1 8.8.8.8 valid=30s;'],
  }

  # Location — OIDC gate via access_by_lua_block (HTTP left open for certbot)
  nginx::resource::location { "${_server}/":
    ensure      => present,
    server      => $_server,
    location    => '/',
    ssl         => $_ssl,
    ssl_only    => $_ssl,
    try_files   => ['$uri', '$uri/', '=404'],
    index_files => ['index.html'],
    raw_append  => [
      # lint:ignore:strict_indent heredoc body confuses the check
      @("OIDC"),
        access_by_lua_block {
          local opts = require("oidc_opts")
          local res, err = require("resty.openidc").authenticate(opts)
          if err then
            ngx.status = 403
            ngx.say(err)
            ngx.exit(ngx.HTTP_FORBIDDEN)
          end
        }
        |-OIDC
      # lint:endignore
    ],
    require     => [
      File['/etc/nginx/lua/oidc_opts.lua'],
      Exec['luarocks install lua-resty-openidc'],
    ],
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
