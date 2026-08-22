require 'spec_helper'

describe 'web::zezav_cz' do
  let(:pre_condition) { 'include nginx' }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'owns the document root by the uploader user' do
        is_expected.to contain_file('/var/www/uploader/zezav.cz')
          .with_ensure('directory')
          .with_owner('uploader')
      end

      it 'serves the apex as the default server over TLS' do
        is_expected.to contain_nginx__resource__server('zezav.cz')
          .with_listen_options('default_server')
          .with_ssl(true)
          .with_ssl_redirect(true)
          .with_ssl_cert('/etc/letsencrypt/live/zezav.cz/fullchain.pem')
          .with_ssl_key('/etc/letsencrypt/live/zezav.cz/privkey.pem')
          .with_www_root('/var/www/uploader/zezav.cz')
      end

      it 'redirects www to the apex' do
        is_expected.to contain_nginx__resource__server('www.zezav.cz').with_ssl(true)
        is_expected.to contain_nginx__resource__location('www.zezav.cz/')
          .with_raw_append(['return 301 https://zezav.cz$request_uri;'])
      end

      it { is_expected.to contain_nginx__resource__location('zezav.cz/').with_ssl_only(true) }

      it 'requests one certificate covering apex and www' do
        is_expected.to contain_class('profile::certbot')
        is_expected.to contain_letsencrypt__certonly('zezav.cz')
          .with_domains(['zezav.cz', 'www.zezav.cz'])
          .with_plugin('nginx')
      end
    end
  end
end
