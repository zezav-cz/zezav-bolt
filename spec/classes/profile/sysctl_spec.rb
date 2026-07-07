require 'spec_helper'

describe 'profile::sysctl' do
  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'writes the hardening config with the default settings' do
        is_expected.to contain_file('/etc/sysctl.d/99-hardening.conf')
          .with_ensure('file')
          .with_owner('root')
          .with_group('root')
          .with_mode('0644')
          .with_content(%r{^net\.ipv4\.conf\.all\.rp_filter = 1$})
          .with_content(%r{^net\.ipv4\.tcp_syncookies = 1$})
          .with_content(%r{^net\.ipv6\.conf\.all\.accept_ra = 0$})
      end

      it 'reloads sysctl when the config changes' do
        is_expected.to contain_exec('sysctl-reload-hardening')
          .with_command('/sbin/sysctl --system')
          .with_refreshonly(true)
          .that_subscribes_to('File[/etc/sysctl.d/99-hardening.conf]')
      end

      context 'with custom settings' do
        let(:params) { { 'settings' => { 'vm.swappiness' => '10' } } }

        it 'renders only the given settings' do
          is_expected.to contain_file('/etc/sysctl.d/99-hardening.conf')
            .with_content("# Managed by Puppet\nvm.swappiness = 10\n")
        end
      end
    end
  end
end
