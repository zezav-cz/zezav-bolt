# @summary Manages time synchronization via systemd-timesyncd
#
# @param ntp_servers
#   Primary NTP servers
# @param fallback_ntp_servers
#   Fallback NTP servers used when primary servers are unreachable
class profile::timesync (
  Array[String[1]] $ntp_servers          = ['0.debian.pool.ntp.org', '1.debian.pool.ntp.org'],
  Array[String[1]] $fallback_ntp_servers = ['2.debian.pool.ntp.org', '3.debian.pool.ntp.org'],
) {
  $ntp_line = $ntp_servers.join(' ')
  $fallback_line = $fallback_ntp_servers.join(' ')

  file { '/etc/systemd/timesyncd.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    # lint:ignore:strict_indent
    content => @("CONF"),
      # Managed by Puppet
      [Time]
      NTP=${ntp_line}
      FallbackNTP=${fallback_line}
      | CONF
    # lint:endignore
  }

  ~> service { 'systemd-timesyncd':
    ensure => running,
    enable => true,
  }
}
