require 'spec_helper'

describe 'profile::node_exporter' do
  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_class('monitoring::node_exporter') }
    end
  end
end
