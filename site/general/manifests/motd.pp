# Installs custom Message of the Day (MOTD) script.
class general::motd {
  file { '/etc/update-motd.d':
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
  }
  file { '/etc/update-motd.d/10-uname':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    source  => 'puppet:///modules/general/motd.sh',
    require => File['/etc/update-motd.d'],
  }
  file { '/etc/motd':
    ensure => 'absent',
  }
}
