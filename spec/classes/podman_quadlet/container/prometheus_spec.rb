require 'spec_helper'

describe 'podman_quadlet::container::prometheus' do
  let(:pre_condition) { 'include podman_quadlet' }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'includes the observability network' do
        is_expected.to contain_class('podman_quadlet::network::observability')
      end

      it 'creates config and state directories' do
        is_expected.to contain_file('/etc/prometheus').with_ensure('directory').with_mode('0755')
        is_expected.to contain_file('/var/lib/prometheus')
          .with_ensure('directory')
          .with_owner('nobody')
          .with_group('nogroup')
          .with_mode('0750')
      end

      it 'renders the prometheus config with all four scrape jobs' do
        is_expected.to contain_file('/etc/prometheus/prometheus.yml')
          .with_mode('0644')
          .with_content(%r{- /etc/prometheus/alerts\.yml})
          .with_content(%r{targets: \['alertmanager:9093'\]})
          .with_content(%r{targets: \['localhost:9090'\]})
          .with_content(%r{targets: \['10\.90\.0\.1:9100'\]})
          .with_content(%r{targets: \['grafana:3000'\]})
          .that_requires('File[/etc/prometheus]')
      end

      it 'ships the starter alert rules' do
        is_expected.to contain_file('/etc/prometheus/alerts.yml')
          .with_mode('0644')
          .with_content(%r{alert: TargetDown})
          .with_content(%r{alert: FilesystemAlmostFull})
          .with_content(%r{alert: MemoryPressure})
          .with_content(%r{alert: CpuHigh})
      end

      describe 'the container quadlet' do
        let(:container_entry) do
          catalogue.resource('Quadlets::Quadlet', 'prometheus.container')[:container_entry]
        end

        it 'runs the pinned image on the observability network' do
          expect(container_entry).to include(
            'ContainerName' => 'prometheus',
            'Image'         => 'docker.io/prom/prometheus:v3.13.0',
            'Network'       => 'observability.network',
          )
        end

        it 'publishes the UI on localhost only' do
          expect(container_entry['PodmanArgs']).to eq(['--publish 127.0.0.1:9090:9090'])
        end

        it 'mounts config read-only and data writable' do
          expect(container_entry['Volume']).to eq(
            [
              '/etc/prometheus:/etc/prometheus:ro',
              '/var/lib/prometheus:/prometheus',
            ],
          )
        end

        it 'passes config path and retention on the command line' do
          expect(container_entry['Exec'])
            .to eq('--config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --storage.tsdb.retention.time=15d')
        end
      end

      context 'with a custom retention' do
        let(:params) { { 'retention' => '90d' } }

        it 'passes it through' do
          entry = catalogue.resource('Quadlets::Quadlet', 'prometheus.container')[:container_entry]
          expect(entry['Exec']).to match(%r{--storage\.tsdb\.retention\.time=90d$})
        end
      end
    end
  end
end
