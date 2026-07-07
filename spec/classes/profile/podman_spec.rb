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

      it 'installs aardvark-dns so dns-enabled podman networks can resolve' do
        is_expected.to contain_package('aardvark-dns').with_ensure('installed')
      end

      it 'pins the netavark network backend via the podman module' do
        is_expected.to contain_ini_setting('/etc/containers/containers.conf [network] network_backend')
          .with_value('"netavark"')
      end

      it { is_expected.not_to contain_file('/etc/containers/containers.conf') }

      it 'leaves the netavark firewall_driver unset while firewalld is unmanaged' do
        is_expected.not_to contain_ini_setting('/etc/containers/containers.conf [network] firewall_driver')
      end
    end
  end
end
