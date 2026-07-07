require 'spec_helper'

describe 'profile::uploader' do
  let(:params) do
    {
      'settings' => [
        {
          'restriction' => 'restrict,command="rrsync /var/www/uploader"',
          'public_keys' => [
            'ssh-ed25519 AAAAkey1 one@example.test',
            'ssh-ed25519 AAAAkey2 two@example.test',
          ],
        },
      ],
    }
  end

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'manages the central authorized_keys directory' do
        is_expected.to contain_file('/etc/ssh/authorized_keys')
          .with_ensure('directory')
          .with_owner('root')
          .with_mode('0755')
      end

      it 'creates the uploader user with restricted keys' do
        is_expected.to contain_accounts__user('uploader')
          .with_ensure('present')
          .with_system(true)
          .with_home('/var/www/uploader')
          .with_shell('/bin/sh')
          .with_purge_sshkeys(true)
          .with_sshkey_custom_path('/etc/ssh/authorized_keys/uploader')
          .with_sshkeys(
            [
              'restrict,command="rrsync /var/www/uploader",no-pty,no-agent-forwarding ssh-ed25519 AAAAkey1 one@example.test',
              'restrict,command="rrsync /var/www/uploader",no-pty,no-agent-forwarding ssh-ed25519 AAAAkey2 two@example.test',
            ],
          )
          .that_requires('File[/etc/ssh/authorized_keys]')
      end
    end
  end
end
