require 'spec_helper'

describe 'profile::podman' do
  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_class('podman') }

      it 'configures unqualified-search registries' do
        is_expected.to contain_file('/etc/containers/registries.conf')
          .with_content(%r{unqualified-search-registries = \["docker\.io", "quay\.io"\]})
      end

      it 'wires podman networking to firewalld with localhost-only port binds' do
        is_expected.to contain_file('/etc/containers/containers.conf')
          .with_content(%r{firewall_driver = "firewalld"})
          .with_content(%r{network_backend = "netavark"})
          .with_content(%r{static_host_port_bind_ip = "127\.0\.0\.1"})
      end
    end
  end
end
