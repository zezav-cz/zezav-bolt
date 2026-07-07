require 'spec_helper'

describe 'monitoring::binary::node_exporter' do
  let(:params) { { 'version' => '1.10.2' } }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      # Debian x86_64 factsets report amd64
      let(:archive_name) { 'node_exporter-1.10.2.linux-amd64.tar.gz' }

      it { is_expected.to compile.with_all_deps }

      it 'downloads the release archive with the checksum from module hiera' do
        is_expected.to contain_archive("/opt/monitoring/node_exporter/#{archive_name}")
          .with_source("https://github.com/prometheus/node_exporter/releases/download/v1.10.2/#{archive_name}")
          .with_checksum('c46e5b6f53948477ff3a19d97c58307394a29fe64a01905646f026ddc32cb65b')
          .with_checksum_type('sha256')
          .with_extract(true)
          .with_creates('/opt/monitoring/node_exporter/node_exporter-1.10.2.linux-amd64/node_exporter')
      end

      it 'links the binary into PATH' do
        is_expected.to contain_file('/usr/local/bin/node_exporter')
          .with_ensure('link')
          .with_target('/opt/monitoring/node_exporter/node_exporter-1.10.2.linux-amd64/node_exporter')
      end

      context 'with an explicit checksum' do
        let(:params) { super().merge('checksum' => 'deadbeef' * 8) }

        it 'uses it instead of the hiera lookup' do
          is_expected.to contain_archive("/opt/monitoring/node_exporter/#{archive_name}")
            .with_checksum('deadbeef' * 8)
        end
      end

      context 'with checksum verification disabled' do
        let(:params) { super().merge('checksum_verify' => false) }

        it 'downloads without a checksum' do
          is_expected.to contain_archive("/opt/monitoring/node_exporter/#{archive_name}")
            .with_checksum(nil)
        end
      end

      context 'with a version missing from the checksum data' do
        let(:params) { super().merge('version' => '0.0.1') }

        it 'refuses to compile' do
          is_expected.to compile.and_raise_error(%r{Checksum for node_exporter version 0\.0\.1})
        end
      end
    end
  end
end
