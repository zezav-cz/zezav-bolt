require 'spec_helper'

describe 'podman_quadlet::container::minecraft' do
  let(:pre_condition) { 'include podman_quadlet' }
  let(:container_entry) do
    catalogue.resource('Quadlets::Quadlet', 'mc.container')[:container_entry]
  end

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'creates the data directories' do
        is_expected.to contain_file('/var/mc').with_ensure('directory').with_mode('0750')
        is_expected.to contain_file('/var/mc/data').with_ensure('directory').with_mode('0750')
      end

      it 'mounts the data directory' do
        expect(container_entry['Volume']).to eq(['/var/mc/data:/data:Z'])
      end

      it 'binds the server port to localhost only by default' do
        expect(container_entry['PodmanArgs']).to eq(['--publish 127.0.0.1:25565:25565'])
      end

      it 'accepts the EULA and sets the default environment' do
        expect(container_entry['Environment']).to include('EULA=TRUE', 'MEMORY=3G', 'MODE=survival', 'ONLINE_MODE=false')
      end

      context 'with a tailscale IP' do
        let(:params) { { 'tailscale_ip' => '100.64.0.5' } }

        it 'additionally binds the port on the VPN address' do
          expect(container_entry['PodmanArgs']).to eq(
            [
              '--publish 127.0.0.1:25565:25565',
              '--publish 100.64.0.5:25565:25565',
            ],
          )
        end
      end

      context 'with environment overrides' do
        let(:params) { { 'environment' => { 'MODE' => 'creative', 'EXTRA' => 'yes' } } }

        it 'merges overrides on top of the defaults' do
          expect(container_entry['Environment']).to include('MODE=creative', 'EXTRA=yes', 'EULA=TRUE')
          expect(container_entry['Environment']).not_to include('MODE=survival')
        end
      end
    end
  end
end
