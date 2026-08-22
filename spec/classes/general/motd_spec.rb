require 'spec_helper'

describe 'general::motd' do
  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_file('/etc/update-motd.d').with_ensure('directory') }

      it 'installs the dynamic MOTD script' do
        is_expected.to contain_file('/etc/update-motd.d/10-uname')
          .with_ensure('file')
          .with_mode('0755')
          .that_requires('File[/etc/update-motd.d]')
      end

      it 'removes the static MOTD' do
        is_expected.to contain_file('/etc/motd').with_ensure('absent')
      end
    end
  end
end
