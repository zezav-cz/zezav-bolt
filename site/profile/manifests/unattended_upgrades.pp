# Configures automatic security updates via unattended-upgrades
#
# @param origins
#   Allowed origin patterns for automatic upgrades
# @param mail
#   Email address for upgrade notifications (undef = no mail)
# @param remove_unused_deps
#   Whether to automatically remove unused dependencies after upgrades
# @param auto_reboot
#   Whether to automatically reboot when required by upgrades
# @param auto_reboot_time
#   Time of day for automatic reboots (HH:MM format)
class profile::unattended_upgrades (
  Array[String]    $origins            = [
    '${distro_id}:${distro_codename}-security',
  ],
  Optional[String] $mail               = undef,
  Boolean          $remove_unused_deps = true,
  Boolean          $auto_reboot        = false,
  String[1]        $auto_reboot_time   = '02:00',
) {
  package { 'unattended-upgrades':
    ensure => installed,
  }

  $origins_list = $origins.map |$o| { "  \"${o}\";" }.join("\n")
  $mail_line = $mail ? {
    undef   => '// Unattended-Upgrade::Mail "";',
    default => "Unattended-Upgrade::Mail \"${mail}\";",
  }

  # lint:ignore:strict_indent
  file { '/etc/apt/apt.conf.d/50unattended-upgrades':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @("CONF"),
      // Managed by Puppet
      Unattended-Upgrade::Allowed-Origins {
      ${origins_list}
      };

      ${mail_line}
      Unattended-Upgrade::Remove-Unused-Dependencies "${bool2str($remove_unused_deps)}";
      Unattended-Upgrade::Automatic-Reboot "${bool2str($auto_reboot)}";
      Unattended-Upgrade::Automatic-Reboot-Time "${auto_reboot_time}";
      | CONF
    require => Package['unattended-upgrades'],
  }

  file { '/etc/apt/apt.conf.d/20auto-upgrades':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @(CONF),
      // Managed by Puppet
      APT::Periodic::Update-Package-Lists "1";
      APT::Periodic::Unattended-Upgrade "1";
      | CONF
    require => Package['unattended-upgrades'],
  }
  # lint:endignore
}
