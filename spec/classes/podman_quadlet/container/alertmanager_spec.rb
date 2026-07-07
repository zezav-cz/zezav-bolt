require 'spec_helper'

describe 'podman_quadlet::container::alertmanager' do
  let(:pre_condition) { 'include podman_quadlet' }
  let(:params) do
    {
      'telegram_bot_token' => '1234567890:TEST-token',
      'telegram_chat_id'   => -100_123_456,
    }
  end

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'includes the observability network' do
        is_expected.to contain_class('podman_quadlet::network::observability')
      end

      it 'creates the state directory for the container user' do
        is_expected.to contain_file('/var/lib/alertmanager')
          .with_ensure('directory')
          .with_owner('nobody')
          .with_group('nogroup')
          .with_mode('0750')
      end

      it 'renders the config readable only by the container user' do
        is_expected.to contain_file('/etc/alertmanager/alertmanager.yml')
          .with_owner('nobody')
          .with_group('nogroup')
          .with_mode('0600')
          .with_content(%r{receiver: telegram})
          .with_content(%r{group_by: \['alertname'\]})
          .with_content(%r{repeat_interval: 4h})
          .with_content(%r{bot_token: '1234567890:TEST-token'})
          .with_content(%r{chat_id: -100123456})
          .that_requires('File[/etc/alertmanager]')
      end

      describe 'the container quadlet' do
        let(:container_entry) do
          catalogue.resource('Quadlets::Quadlet', 'alertmanager.container')[:container_entry]
        end

        it 'runs the pinned image on the observability network' do
          expect(container_entry).to include(
            'ContainerName' => 'alertmanager',
            'Image'         => 'docker.io/prom/alertmanager:v0.33.0',
            'Network'       => 'observability.network',
          )
        end

        it 'publishes the UI on localhost only' do
          expect(container_entry['PodmanArgs']).to eq(['--publish 127.0.0.1:9093:9093'])
        end

        it 'mounts config read-only and data writable' do
          expect(container_entry['Volume']).to eq(
            [
              '/etc/alertmanager:/etc/alertmanager:ro',
              '/var/lib/alertmanager:/alertmanager',
            ],
          )
        end
      end
    end
  end
end
