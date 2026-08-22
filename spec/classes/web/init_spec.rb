require 'spec_helper'

describe 'web' do
  # In production profile::base declares the firewall before the hiera
  # classes; web reads $profile::server_firewall::public_zone directly.
  let(:pre_condition) { 'include profile::server_firewall' }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'opens HTTP and HTTPS in the firewall public zone' do
        is_expected.to contain_firewalld_service('Allow HTTP').with_zone('block').with_service('http')
        is_expected.to contain_firewalld_service('Allow HTTPS').with_zone('block').with_service('https')
      end

      it 'configures nginx with purging and the lua OIDC settings' do
        is_expected.to contain_class('nginx')
          .with_confd_purge(true)
          .with_server_purge(true)
          .with_http_cfg_append(
            'lua_package_path'            => '"/etc/nginx/lua/?.lua;;"',
            'lua_ssl_trusted_certificate' => '/etc/ssl/certs/ca-certificates.crt',
            'lua_ssl_verify_depth'        => '3',
          )
      end

      it 'creates the web roots' do
        is_expected.to contain_file('/var/www').with_ensure('directory').with_owner('www-data')
        is_expected.to contain_file('/var/www/uploader')
          .with_ensure('directory')
          .with_owner('uploader')
          .with_group('www-data')
          .that_requires('File[/var/www]')
      end

      %w[web::zezav_cz web::blog_zezav_cz web::dir_zezav_cz web::private_zezav_cz].each do |site|
        it { is_expected.to contain_class(site) }
      end

      context 'with firewall rules disabled' do
        let(:params) { { 'firewall_http' => false, 'firewall_https' => false } }

        it { is_expected.not_to contain_firewalld_service('Allow HTTP') }
        it { is_expected.not_to contain_firewalld_service('Allow HTTPS') }
      end
    end
  end
end
