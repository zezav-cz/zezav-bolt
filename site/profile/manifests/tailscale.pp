# @summary Installs and manages Tailscale VPN client
#
# @param release
#   Debian release codename for the Tailscale apt repository
class profile::tailscale (
  String[1] $release = $facts['os']['distro']['codename'],
) {
  apt::keyring { 'tailscale-archive-keyring.gpg':
    source => 'https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg',
  }

  apt::source { 'tailscale':
    location => 'https://pkgs.tailscale.com/stable/debian',
    release  => $release,
    repos    => 'main',
    keyring  => '/etc/apt/keyrings/tailscale-archive-keyring.gpg',
    require  => Apt::Keyring['tailscale-archive-keyring.gpg'],
  }

  package { 'tailscale':
    ensure  => installed,
    require => Apt::Source['tailscale'],
  }
}
