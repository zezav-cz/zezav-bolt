require 'spec_helper'

describe 'podman_quadlet::volume' do
  let(:pre_condition) { 'include podman_quadlet' }
  let(:title) { 'mydata' }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'creates a named volume quadlet' do
        is_expected.to contain_quadlets__quadlet('mydata.volume')
          .with_ensure('present')
          .with_mode('0444')
          .with_volume_entry('VolumeName' => 'mydata')
          .that_requires('Class[podman_quadlet]')
      end
    end
  end
end
