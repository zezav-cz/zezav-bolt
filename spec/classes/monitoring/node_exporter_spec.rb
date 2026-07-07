require 'spec_helper'

describe 'monitoring::node_exporter' do
  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_class('monitoring::binary::node_exporter').with_version('1.10.2') }

      it 'runs node_exporter as an enabled systemd service' do
        is_expected.to contain_systemd__unit_file('node_exporter.service')
          .with_enable(true)
          .with_active(true)
          .with_content(%r{ExecStart=/usr/local/bin/node_exporter})
          .that_requires('Class[monitoring::binary::node_exporter]')
      end
    end
  end
end
