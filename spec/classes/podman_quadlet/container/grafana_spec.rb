require 'spec_helper'

describe 'podman_quadlet::container::grafana' do
  let(:pre_condition) { 'include podman_quadlet' }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'includes the observability network' do
        is_expected.to contain_class('podman_quadlet::network::observability')
      end

      it 'creates the state directory for the grafana user (472)' do
        is_expected.to contain_file('/var/lib/grafana')
          .with_ensure('directory')
          .with_owner('472')
          .with_group('472')
          .with_mode('0750')
      end

      it 'provisions the prometheus datasource' do
        is_expected.to contain_file('/etc/grafana/provisioning/datasources/prometheus.yaml')
          .with_mode('0644')
          .with_content(%r{type: prometheus})
          .with_content(%r{url: http://prometheus:9090})
          .with_content(%r{isDefault: true})
          .that_requires('File[/etc/grafana/provisioning/datasources]')
      end

      describe 'the container quadlet' do
        let(:container_entry) do
          catalogue.resource('Quadlets::Quadlet', 'grafana.container')[:container_entry]
        end

        it 'runs the pinned image on the observability network' do
          expect(container_entry).to include(
            'ContainerName' => 'grafana',
            'Image'         => 'docker.io/grafana/grafana:13.1.0',
            'Network'       => 'observability.network',
          )
        end

        it 'publishes the UI on localhost only' do
          expect(container_entry['PodmanArgs']).to eq(['--publish 127.0.0.1:3000:3000'])
        end

        it 'mounts only the datasources provisioning dir read-only, data writable' do
          expect(container_entry['Volume']).to eq(
            [
              '/etc/grafana/provisioning/datasources:/etc/grafana/provisioning/datasources:ro',
              '/var/lib/grafana:/var/lib/grafana',
            ],
          )
        end
      end
    end
  end
end
