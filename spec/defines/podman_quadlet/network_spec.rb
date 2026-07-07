require 'spec_helper'

describe 'podman_quadlet::network' do
  let(:pre_condition) { 'include podman_quadlet' }
  let(:title) { 'appnet' }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'creates a bridge network quadlet by default' do
        is_expected.to contain_quadlets__quadlet('appnet.network')
          .with_ensure('present')
          .with_active(true)
          .with_network_entry('NetworkName' => 'appnet', 'Driver' => 'bridge')
          .that_requires('Class[podman_quadlet]')
      end

      context 'with subnet, gateway, ipv6, and internal' do
        let(:params) do
          {
            'subnet'   => '10.89.0.0/24',
            'gateway'  => '10.89.0.1',
            'ipv6'     => true,
            'internal' => true,
          }
        end

        it 'renders all network settings' do
          is_expected.to contain_quadlets__quadlet('appnet.network')
            .with_network_entry(
              'NetworkName' => 'appnet',
              'Driver'      => 'bridge',
              'Subnet'      => '10.89.0.0/24',
              'Gateway'     => '10.89.0.1',
              'IPv6'        => true,
              'Internal'    => true,
            )
        end
      end
    end
  end
end
