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

      it 'bootstraps over plain HTTP while no certificate exists' do
        is_expected.to contain_nginx__resource__server('blog.zezav.cz')
          .with_ssl(false)
          .with_ssl_redirect(false)
          .with_ssl_cert(nil)
          .with_www_root('/var/www/uploader/blog.zezav.cz')
      end

      it 'requests a certificate after nginx is up' do
        is_expected.to contain_letsencrypt__certonly('blog.zezav.cz')
          .with_domains(['blog.zezav.cz'])
          .with_plugin('nginx')
          .that_requires('Class[nginx::service]')
      end

      context 'with an issued certificate' do
        let(:facts) do
          os_facts.merge('letsencrypt_directory' => { 'blog.zezav.cz' => '/etc/letsencrypt/live/blog.zezav.cz' })
        end

        it 'serves the blog over TLS with redirect' do
          is_expected.to contain_nginx__resource__server('blog.zezav.cz')
            .with_ssl(true)
            .with_ssl_redirect(true)
            .with_ssl_cert('/etc/letsencrypt/live/blog.zezav.cz/fullchain.pem')
            .with_ssl_key('/etc/letsencrypt/live/blog.zezav.cz/privkey.pem')
        end

        it { is_expected.to contain_nginx__resource__location('blog.zezav.cz/').with_ssl_only(true) }
      end
    end
  end
end
