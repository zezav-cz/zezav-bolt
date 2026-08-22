require 'spec_helper'

describe 'profile::base' do
  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'creates the home directory roots' do
        is_expected.to contain_file('/home/system').with_ensure('directory').with_mode('0755')
        is_expected.to contain_file('/home/users').with_ensure('directory').with_mode('0755')
      end

      it { is_expected.to contain_exec('puppet-gem-cleanup') }

      %w[
        accounts sudo ssh locales apt
        general::motd
        profile::server_firewall
        profile::unattended_upgrades
        profile::timesync
        profile::sysctl
        profile::tailscale
      ].each do |cls|
        it { is_expected.to contain_class(cls) }
      end
    end
  end
end
