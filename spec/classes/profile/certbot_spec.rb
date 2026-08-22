require 'spec_helper'

describe 'profile::certbot' do
  let(:params) { { 'email' => 'certbot@example.test' } }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'configures letsencrypt with ECDSA keys and a renewal cron' do
        is_expected.to contain_class('letsencrypt')
          .with_email('certbot@example.test')
          .with_key_type('ecdsa')
          .with_renew_cron_ensure('present')
          .with_renew_cron_hour(18)
          .with_cron_scripts_path('/var/lib/letsencrypt-puppet')
          .with_config_dir('/etc/letsencrypt')
      end

      it { is_expected.to contain_class('letsencrypt::plugin::nginx') }

      context 'with nginx plugin disabled' do
        let(:params) { super().merge('nginx' => false) }

        it { is_expected.not_to contain_class('letsencrypt::plugin::nginx') }
      end

      context 'with rsa key type' do
        let(:params) { super().merge('key_type' => 'rsa') }

        it { is_expected.to contain_class('letsencrypt').with_key_type('rsa') }
      end
    end
  end
end
