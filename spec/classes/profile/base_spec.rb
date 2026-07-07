require 'spec_helper'

describe 'profile::base' do
  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_exec('puppet-gem-cleanup') }

      %w[
        accounts sudo ssh locales apt
        general::motd
        profile::unattended_upgrades
        profile::timesync
        profile::sysctl
        profile::node_exporter
      ].each do |cls|
        it { is_expected.to contain_class(cls) }
      end
    end
  end
end
