class profile::base {
  file { ['/home/system','/home/users']:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
  include accounts
  include sudo
  include ssh
  # include hostkeys
  include locales
  # include systemd
  include general::motd
  include apt

  lookup('classes').include

  include profile::server_firewall
}
