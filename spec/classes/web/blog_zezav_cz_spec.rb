require 'spec_helper'

describe 'web::blog_zezav_cz' do
  let(:pre_condition) { 'include nginx' }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'owns the document root by the uploader user' do
        is_expected.to contain_file('/var/www/uploader/blog.zezav.cz')
          .with_ensure('directory')
          .with_owner('uploader')
      end

      it 'serves the blog over TLS with redirect' do
        is_expected.to contain_nginx__resource__server('blog.zezav.cz')
          .with_ssl(true)
          .with_ssl_redirect(true)
          .with_www_root('/var/www/uploader/blog.zezav.cz')
      end

      it { is_expected.to contain_nginx__resource__location('blog.zezav.cz/').with_ssl_only(true) }

      it 'requests a certificate' do
        is_expected.to contain_letsencrypt__certonly('blog.zezav.cz')
          .with_domains(['blog.zezav.cz'])
          .with_plugin('nginx')
      end
    end
  end
end
