# Installs and configures podman container runtime.
class profile::podman {
  include podman

  file { '/etc/containers/registries.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "unqualified-search-registries = [\"docker.io\", \"quay.io\"]\n",
  }

  file { '/etc/containers/containers.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "[network]\nfirewall_driver = \"firewalld\"\nnetwork_backend = \"netavark\"\nstatic_host_port_bind_ip = \"127.0.0.1\"\n",
  }
}
