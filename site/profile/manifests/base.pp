# @summary Base profile applied to all nodes.
#
# Sets up core infrastructure: user accounts and sudo/SSH access,
# APT and locales, unattended upgrades, time sync, sysctl hardening,
# and node_exporter monitoring. Also pulls in per-node classes from
# the hiera `classes` key.
class profile::base {
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

  # Disabled while firewalld is unmanaged — see TODO.md
  # include profile::server_firewall

  # Per-node classes from hiera
  lookup('classes').include
  include profile::unattended_upgrades
  include profile::timesync
  include profile::sysctl
  # include profile::tailscale
  include profile::node_exporter
}
