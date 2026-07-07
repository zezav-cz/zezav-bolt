# @summary Installs libnginx-mod-http-lua and lua-resty-openidc for OIDC authentication.
class profile::nginx_oidc {
  package { ['libnginx-mod-http-lua', 'luarocks', 'lua-cjson']:
    ensure => installed,
  }

  file { '/etc/nginx/lua':
    ensure  => directory,
    owner   => 'root',
    group   => 'www-data',
    mode    => '0750',
    require => Package['libnginx-mod-http-lua'],
  }

  # Install each dependency explicitly — luarocks auto-resolution is unreliable
  # when Debian has partial resty installs that shadow missing transitive deps.
  exec { 'luarocks install lua-resty-string':
    command => '/usr/bin/luarocks install lua-resty-string',
    unless  => '/usr/bin/luarocks show lua-resty-string',
    require => Package['luarocks'],
  }

  exec { 'luarocks install lua-resty-http':
    command => '/usr/bin/luarocks install lua-resty-http',
    unless  => '/usr/bin/luarocks show lua-resty-http',
    require => Exec['luarocks install lua-resty-string'],
  }

  exec { 'luarocks install lua-resty-session':
    command => '/usr/bin/luarocks install lua-resty-session',
    unless  => '/usr/bin/luarocks show lua-resty-session',
    require => Package['luarocks'],
  }

  exec { 'luarocks install lua-resty-jwt':
    command => '/usr/bin/luarocks install lua-resty-jwt',
    unless  => '/usr/bin/luarocks show lua-resty-jwt',
    require => Package['luarocks'],
  }

  exec { 'luarocks install lua-resty-openidc':
    command => '/usr/bin/luarocks install lua-resty-openidc',
    unless  => '/usr/bin/luarocks show lua-resty-openidc',
    require => [
      Exec['luarocks install lua-resty-http'],
      Exec['luarocks install lua-resty-session'],
      Exec['luarocks install lua-resty-jwt'],
    ],
  }
}
