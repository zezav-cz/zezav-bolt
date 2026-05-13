# Base profile applied to all nodes.
# Sets up core infrastructure: user directories, system services,
# firewall, and Tailscale VPN.
class profile::base {
  # Home directories
  file { ['/home/system', '/home/users']:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  exec { 'puppet-gem-cleanup':
    command => '/opt/puppetlabs/puppet/bin/gem cleanup',
    onlyif  => '/opt/puppetlabs/puppet/bin/gem list --duplicates 2>/dev/null | grep -q .',
    path    => ['/usr/bin', '/bin'],
  }

  # Core system modules
  include accounts
  include sudo
  include ssh
  include locales
  include apt
  include general::motd

  # Firewall must be declared before hiera classes so they can reference
  # $profile::server_firewall::public_zone
  include profile::server_firewall

  # Per-node classes from hiera
  lookup('classes').include
  include profile::unattended_upgrades
  include profile::timesync
  include profile::sysctl
  include profile::tailscale
}
