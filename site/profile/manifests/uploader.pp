# @summary Restricted rsync-only upload account for the web content tree.
#
# Creates the `uploader` system user (home `/var/www/uploader`, no managed
# home directory) whose SSH keys live in the central
# `/etc/ssh/authorized_keys/uploader` file and are wrapped with per-key
# restrictions (typically `rrsync /var/www/uploader`), so the account can
# only sync web content.
#
# @param settings
#   Array of SSH key configurations. Each entry contains 'restriction' (SSH command restriction string) and 'public_keys' (array of public key strings)
class profile::uploader (
  Array[Struct[{
        'restriction' => String[1],
        'public_keys' => Array[String[1]],
  }],1] $settings
) {
  file { '/etc/ssh/authorized_keys':
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    recurse => true,
  }

  $_authorized_keys = $settings.reduce([]) |$memo, $item| {
    $public_keys = $item['public_keys']
    $restriction = $item['restriction']
    $keys = $public_keys.map |$key| {
      "${restriction},no-pty,no-agent-forwarding ${key}"
    }
    $memo + $keys
  }

  accounts::user { 'uploader':
    ensure             => present,
    comment            => 'Uploader System User',
    create_group       => true,
    managehome         => false,
    purge_user_home    => false,
    managevim          => false,
    membership         => 'inclusive',
    purge_sshkeys      => true,
    shell              => '/bin/sh',
    home               => '/var/www/uploader',
    system             => true,
    sshkeys            => $_authorized_keys,
    sshkey_custom_path => '/etc/ssh/authorized_keys/uploader',
    require            => File['/etc/ssh/authorized_keys'],
  }
}
