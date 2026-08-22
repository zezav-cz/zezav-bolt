require 'spec_helper'

describe 'profile::nginx_oidc' do
  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      %w[libnginx-mod-http-lua luarocks lua-cjson].each do |pkg|
        it { is_expected.to contain_package(pkg).with_ensure('installed') }
      end

      it 'creates the lua config directory readable by nginx' do
        is_expected.to contain_file('/etc/nginx/lua')
          .with_ensure('directory')
          .with_owner('root')
          .with_group('www-data')
          .with_mode('0750')
          .that_requires('Package[libnginx-mod-http-lua]')
      end

      it 'installs each lua rock idempotently' do
        %w[lua-resty-string lua-resty-http lua-resty-session lua-resty-jwt lua-resty-openidc].each do |rock|
          is_expected.to contain_exec("luarocks install #{rock}")
            .with_command("/usr/bin/luarocks install #{rock}")
            .with_unless("/usr/bin/luarocks show #{rock}")
        end
      end

      it 'installs openidc only after its transitive deps' do
        is_expected.to contain_exec('luarocks install lua-resty-openidc')
          .that_requires(
            [
              'Exec[luarocks install lua-resty-http]',
              'Exec[luarocks install lua-resty-session]',
              'Exec[luarocks install lua-resty-jwt]',
            ],
          )
      end
    end
  end
end
