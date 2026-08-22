require 'spec_helper'

describe 'podman_quadlet::container::headscale' do
  let(:pre_condition) { 'include podman_quadlet' }
  let(:params) do
    {
      'server_url'     => 'https://vpn.example.test',
      'acme_email'     => 'acme@example.test',
      'tls_hostname'   => 'vpn.example.test',
      'base_domain'    => 'ts.example.test',
      'oidc_issuer'    => 'https://idp.example.test',
      'oidc_client_id' => 'headscale-client',
    }
  end

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:node_ip) { os_facts[:networking]['ip'] }

      it { is_expected.to compile.with_all_deps }

      it 'creates config and state directories' do
        is_expected.to contain_file('/etc/headscale').with_ensure('directory').with_mode('0750')
        is_expected.to contain_file('/var/lib/headscale').with_ensure('directory').with_mode('0750')
      end

      it 'renders the headscale config' do
        is_expected.to contain_file('/etc/headscale/config.yaml')
          .with_mode('0640')
          .with_content(%r{^server_url: https://vpn\.example\.test$})
          .with_content(%r{acme_email: "acme@example\.test"})
          .with_content(%r{base_domain: ts\.example\.test})
          .with_content(%r{issuer: "https://idp\.example\.test"})
          .with_content(%r{client_id: "headscale-client"})
          .that_requires('File[/etc/headscale]')
      end

      it 'opens HTTPS, HTTP, WireGuard, and STUN across the zones' do
        %w[public block drop internal trusted].each do |zone|
          is_expected.to contain_firewalld_service("Allow HTTPS - headscale - #{zone}").with_zone(zone)
          is_expected.to contain_firewalld_service("Allow HTTP - headscale ACME - #{zone}").with_zone(zone)
          is_expected.to contain_firewalld_port("Tailscale STUN - headscale - #{zone}")
            .with_zone(zone)
            .with_port('3478')
            .with_protocol('udp')
        end
        %w[public internal block trusted].each do |zone|
          is_expected.to contain_firewalld_port("Allow WireGuard - headscale - #{zone}")
            .with_zone(zone)
            .with_port('41641')
        end
      end

      describe 'the container quadlet' do
        let(:container_entry) do
          catalogue.resource('Quadlets::Quadlet', 'headscale.container')[:container_entry]
        end

        it 'runs headscale read-only in serve mode' do
          expect(container_entry).to include(
            'ContainerName' => 'headscale',
            'Image'         => 'docker.io/headscale/headscale:0.28',
            'ReadOnly'      => true,
            'Exec'          => 'serve',
          )
        end

        it 'publishes HTTP on all interfaces and HTTPS on the node IP plus localhost' do
          expect(container_entry['PodmanArgs']).to eq(
            [
              '--publish 0.0.0.0:80:80/tcp',
              "--publish #{node_ip}:443:4443/tcp",
              '--publish 127.0.0.1:443:4443/tcp',
            ],
          )
        end

        it 'mounts config read-only and state writable' do
          expect(container_entry['Volume']).to eq(
            [
              '/etc/headscale:/etc/headscale:ro',
              '/var/lib/headscale:/var/lib/headscale',
            ],
          )
        end
      end

      context 'with firewall management disabled' do
        let(:params) { super().merge('fw' => false) }

        it { is_expected.not_to contain_firewalld_service('Allow HTTPS - headscale - public') }
        it { is_expected.not_to contain_firewalld_port('Allow WireGuard - headscale - public') }
      end
    end
  end
end
