# Manages the private.zezav.cz website, protected by OIDC via lua-resty-openidc.
#
# @param oidc_discovery_url OIDC provider discovery URL
# @param oidc_client_id     OIDC client ID registered for this site
# @param oidc_client_secret OIDC client secret
# @param oidc_session_secret Random secret used to sign session cookies (min 32 chars)
class web::private_zezav_cz (
  String $oidc_discovery_url,
  String $oidc_client_id,
  String $oidc_client_secret  = '',
  String $oidc_session_secret,
) {
  $_server = 'private.zezav.cz'

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
    ssl                  => true,
    ssl_cert             => "/etc/letsencrypt/live/${_server}/fullchain.pem",
    ssl_key              => "/etc/letsencrypt/live/${_server}/privkey.pem",
    ssl_redirect         => true,
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
    ssl         => true,
    ssl_only    => true,
    try_files   => ['$uri', '$uri/', '=404'],
    index_files => ['index.html'],
    raw_append  => [
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
    ],
    require     => [
      File['/etc/nginx/lua/oidc_opts.lua'],
      Exec['luarocks install lua-resty-openidc'],
    ],
  }

  # TLS certificate
  include profile::certbot

  letsencrypt::certonly { $_server:
    ensure  => present,
    domains => [$_server],
    plugin  => 'nginx',
  }
}
