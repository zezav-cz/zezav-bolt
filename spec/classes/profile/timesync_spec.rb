require 'spec_helper'

describe 'profile::timesync' do
  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'configures timesyncd with the Debian NTP pool' do
        is_expected.to contain_file('/etc/systemd/timesyncd.conf')
          .with_ensure('file')
          .with_mode('0644')
          .with_content(%r{^NTP=0\.debian\.pool\.ntp\.org 1\.debian\.pool\.ntp\.org$})
          .with_content(%r{^FallbackNTP=2\.debian\.pool\.ntp\.org 3\.debian\.pool\.ntp\.org$})
      end

      it 'restarts timesyncd on config changes' do
        is_expected.to contain_service('systemd-timesyncd')
          .with_ensure('running')
          .with_enable(true)
          .that_subscribes_to('File[/etc/systemd/timesyncd.conf]')
      end

      context 'with custom servers' do
        let(:params) { { 'ntp_servers' => ['ntp.example.test'] } }

        it { is_expected.to contain_file('/etc/systemd/timesyncd.conf').with_content(%r{^NTP=ntp\.example\.test$}) }
      end
    end
  end
end
