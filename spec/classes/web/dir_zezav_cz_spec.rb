require 'spec_helper'

describe 'web::dir_zezav_cz' do
  let(:pre_condition) { 'include nginx' }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'serves the listing without forcing an HTTPS redirect' do
        is_expected.to contain_nginx__resource__server('dir.zezav.cz')
          .with_ssl(true)
          .with_ssl_redirect(false)
      end

      it 'autoindexes in HTML and reroutes JSON Accept headers' do
        is_expected.to contain_nginx__resource__location('dir.zezav.cz/')
          .with_autoindex('on')
          .with_raw_prepend(%r{http_accept.*application/json.*rewrite \^/\(\.\*\)\$ /_json_output/\$1 last}m)
      end

      it 'exposes the JSON view only internally' do
        is_expected.to contain_nginx__resource__location('dir.zezav.cz/_json_output')
          .with_internal(true)
          .with_autoindex_format('json')
          .with_location_cfg_append('alias' => '/var/www/uploader/dir.zezav.cz/')
      end

      it 'requests a certificate' do
        is_expected.to contain_letsencrypt__certonly('dir.zezav.cz').with_domains(['dir.zezav.cz'])
      end
    end
  end
end
