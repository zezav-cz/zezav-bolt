require 'spec_helper'

describe 'web::private_zezav_cz' do
  let(:pre_condition) { 'include nginx' }
  let(:params) do
    {
      'oidc_discovery_url'  => 'https://idp.example.test/.well-known/openid-configuration',
      'oidc_client_id'      => 'client-123',
      'oidc_session_secret' => 'a-session-secret-that-is-long-enough',
    }
  end

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_class('profile::nginx_oidc') }

      it 'renders the lua OIDC options with PKCE and no client secret' do
        is_expected.to contain_file('/etc/nginx/lua/oidc_opts.lua')
          .with_owner('root')
          .with_group('www-data')
          .with_mode('0640')
          .with_content(%r{redirect_uri\s+= "https://private\.zezav\.cz/redirect_uri"})
          .with_content(%r{discovery\s+= "https://idp\.example\.test/\.well-known/openid-configuration"})
          .with_content(%r{client_id\s+= "client-123"})
          .with_content(%r{use_pkce\s+= true})
          .with_content(%r{session_secret\s+= "a-session-secret-that-is-long-enough"})
          .with_content(%r{post_logout_redirect_uri\s+= "https://zezav\.cz"})
          .that_notifies('Service[nginx]')
      end

      it 'omits client_secret when empty' do
        is_expected.to contain_file('/etc/nginx/lua/oidc_opts.lua').without_content(%r{client_secret})
      end

      context 'with a confidential client secret' do
        let(:params) { super().merge('oidc_client_secret' => 'hush') }

        it 'renders client_secret' do
          is_expected.to contain_file('/etc/nginx/lua/oidc_opts.lua')
            .with_content(%r{client_secret\s+= "hush"})
        end
      end

      it 'bootstraps over plain HTTP while no certificate exists' do
        is_expected.to contain_nginx__resource__server('private.zezav.cz')
          .with_ssl(false)
          .with_ssl_redirect(false)
          .with_ssl_cert(nil)
          .with_raw_prepend(['resolver 1.1.1.1 8.8.8.8 valid=30s;'])
      end

      it 'gates the location behind the OIDC lua block' do
        is_expected.to contain_nginx__resource__location('private.zezav.cz/')
          .that_requires(
            [
              'File[/etc/nginx/lua/oidc_opts.lua]',
              'Exec[luarocks install lua-resty-openidc]',
            ],
          )
        raw_append = catalogue.resource('Nginx::Resource::Location', 'private.zezav.cz/')[:raw_append]
        expect(raw_append.join).to match(%r{access_by_lua_block}).and match(%r{resty\.openidc.*authenticate}m)
      end

      it 'requests a certificate after nginx is up' do
        is_expected.to contain_letsencrypt__certonly('private.zezav.cz')
          .with_domains(['private.zezav.cz'])
          .that_requires('Class[nginx::service]')
      end

      context 'with an issued certificate' do
        let(:facts) do
          os_facts.merge(
            'letsencrypt_directory' => { 'private.zezav.cz' => '/etc/letsencrypt/live/private.zezav.cz' },
          )
        end

        it 'serves the site over TLS with an explicit resolver' do
          is_expected.to contain_nginx__resource__server('private.zezav.cz')
            .with_ssl(true)
            .with_ssl_redirect(true)
            .with_ssl_cert('/etc/letsencrypt/live/private.zezav.cz/fullchain.pem')
            .with_raw_prepend(['resolver 1.1.1.1 8.8.8.8 valid=30s;'])
        end

        it { is_expected.to contain_nginx__resource__location('private.zezav.cz/').with_ssl_only(true) }
      end
    end
  end
end
