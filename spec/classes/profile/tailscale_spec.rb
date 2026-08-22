require 'spec_helper'

describe 'profile::tailscale' do
  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:codename) { os_facts[:os]['distro']['codename'] }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_apt__keyring('tailscale-archive-keyring.gpg') }

      it "adds the tailscale repo for the node's own release" do
        is_expected.to contain_apt__source('tailscale')
          .with_location('https://pkgs.tailscale.com/stable/debian')
          .with_release(codename)
          .with_repos('main')
          .with_keyring('/etc/apt/keyrings/tailscale-archive-keyring.gpg')
          .that_requires('Apt::Keyring[tailscale-archive-keyring.gpg]')
      end

      it 'installs tailscale from that repo' do
        is_expected.to contain_package('tailscale')
          .with_ensure('installed')
          .that_requires('Apt::Source[tailscale]')
      end
    end
  end
end
