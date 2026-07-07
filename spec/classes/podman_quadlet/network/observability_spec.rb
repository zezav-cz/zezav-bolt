require 'spec_helper'

describe 'podman_quadlet::network::observability' do
  let(:pre_condition) { 'include podman_quadlet' }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'declares the observability network with the fixed subnet' do
        is_expected.to contain_podman_quadlet__network('observability')
          .with_subnet('10.90.0.0/24')
          .with_gateway('10.90.0.1')
      end

      it 'renders the expected network entry' do
        entry = catalogue.resource('Quadlets::Quadlet', 'observability.network')[:network_entry]
        expect(entry).to eq(
          'NetworkName' => 'observability',
          'Driver'      => 'bridge',
          'Subnet'      => '10.90.0.0/24',
          'Gateway'     => '10.90.0.1',
        )
      end
    end
  end
end
