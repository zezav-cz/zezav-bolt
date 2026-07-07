# @summary Installs and configures podman container runtime.
#
# containers.conf is managed through the podman module's containers_options
# (Ini_setting per key). Only network_backend is pinned: quadlet .network
# units require netavark. firewall_driver is deliberately unset — netavark's
# firewalld driver needs a running firewalld daemon, which is not managed
# right now (see TODO.md, "Re-enable profile::server_firewall"). Private
# ports are protected by per-container 127.0.0.1 binds in
# podman_quadlet::container, not by a global setting.
class profile::podman {
  class { 'podman':
    containers_options => {
      'network' => {
        'network_backend' => '"netavark"',
      },
    },
  }

  # netavark only Recommends aardvark-dns, and the cloud image sets
  # APT::Install-Recommends "false" — without it, containers on
  # dns_enabled networks get the gateway as sole nameserver with nothing
  # listening, breaking both container-name and external DNS.
  package { 'aardvark-dns':
    ensure => installed,
  }

  # The podman module has no registries.conf support, so manage it directly.
  file { '/etc/containers/registries.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "unqualified-search-registries = [\"docker.io\", \"quay.io\"]\n",
  }
}
