# Applies kernel network hardening via sysctl
#
# @param settings
#   Hash of sysctl key-value pairs to apply
class profile::sysctl (
  Hash[String[1], String[1]] $settings = {
    # IP spoofing protection
    'net.ipv4.conf.all.rp_filter'          => '1',
    'net.ipv4.conf.default.rp_filter'      => '1',

    # Disable ICMP redirects (prevent MITM)
    'net.ipv4.conf.all.accept_redirects'   => '0',
    'net.ipv4.conf.default.accept_redirects' => '0',
    'net.ipv6.conf.all.accept_redirects'   => '0',
    'net.ipv6.conf.default.accept_redirects' => '0',
    'net.ipv4.conf.all.send_redirects'     => '0',
    'net.ipv4.conf.default.send_redirects' => '0',

    # Disable source routing
    'net.ipv4.conf.all.accept_source_route'   => '0',
    'net.ipv4.conf.default.accept_source_route' => '0',
    'net.ipv6.conf.all.accept_source_route'   => '0',
    'net.ipv6.conf.default.accept_source_route' => '0',

    # Log martian packets
    'net.ipv4.conf.all.log_martians'       => '1',

    # Ignore ICMP broadcast requests
    'net.ipv4.icmp_echo_ignore_broadcasts' => '1',

    # Ignore bogus ICMP error responses
    'net.ipv4.icmp_ignore_bogus_error_responses' => '1',

    # SYN flood protection
    'net.ipv4.tcp_syncookies'              => '1',

    # Disable IPv6 router advertisements
    'net.ipv6.conf.all.accept_ra'          => '0',
    'net.ipv6.conf.default.accept_ra'      => '0',
  },
) {
  $sysctl_lines = $settings.map |$key, $value| { "${key} = ${value}" }.join("\n")

  file { '/etc/sysctl.d/99-hardening.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "# Managed by Puppet\n${sysctl_lines}\n",
  }

  ~> exec { 'sysctl-reload-hardening':
    command     => '/sbin/sysctl --system',
    refreshonly => true,
  }
}
