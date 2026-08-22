require 'spec_helper'

describe 'podman_quadlet' do
  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_class('profile::podman') }

      it 'sets up quadlet directories and purges unmanaged files' do
        is_expected.to contain_class('quadlets')
          .with_manage_package(false)
          .with_manage_service(false)
          .with_create_quadlet_dir(true)
          .with_purge_quadlet_dir(true)
      end

      context 'with purging disabled' do
        let(:params) { { 'purge_quadlet_dir' => false } }

        it { is_expected.to contain_class('quadlets').with_purge_quadlet_dir(false) }
      end
    end
  end
end
