require 'spec_helper'

describe 'profile::unattended_upgrades' do
  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_package('unattended-upgrades').with_ensure('installed') }

      it 'allows only the security origin by default' do
        is_expected.to contain_file('/etc/apt/apt.conf.d/50unattended-upgrades')
          .with_content(%r{^  "\$\{distro_id\}:\$\{distro_codename\}-security";$})
          .with_content(%r{^// Unattended-Upgrade::Mail "";$})
          .with_content(%r{^Unattended-Upgrade::Remove-Unused-Dependencies "true";$})
          .with_content(%r{^Unattended-Upgrade::Automatic-Reboot "false";$})
          .that_requires('Package[unattended-upgrades]')
      end

      it 'enables periodic updates' do
        is_expected.to contain_file('/etc/apt/apt.conf.d/20auto-upgrades')
          .with_content(%r{^APT::Periodic::Update-Package-Lists "1";$})
          .with_content(%r{^APT::Periodic::Unattended-Upgrade "1";$})
      end

      context 'with mail and auto-reboot enabled' do
        let(:params) do
          {
            'mail'             => 'root@example.test',
            'auto_reboot'      => true,
            'auto_reboot_time' => '04:30',
          }
        end

        it 'writes the mail and reboot directives' do
          is_expected.to contain_file('/etc/apt/apt.conf.d/50unattended-upgrades')
            .with_content(%r{^Unattended-Upgrade::Mail "root@example\.test";$})
            .with_content(%r{^Unattended-Upgrade::Automatic-Reboot "true";$})
            .with_content(%r{^Unattended-Upgrade::Automatic-Reboot-Time "04:30";$})
        end
      end
    end
  end
end
