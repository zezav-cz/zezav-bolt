require 'spec_helper'

describe 'profile::server_firewall' do
  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      # Interface mix covering every classification branch.
      let(:facts) do
        os_facts.merge(
          networking: os_facts[:networking].merge(
            'interfaces' => {
              'eth0'       => {},
              'lo'         => {},
              'tailscale0' => {},
              'podman0'    => {},
              'veth1234'   => {},
            },
          ),
        )
      end

      it { is_expected.to compile.with_all_deps }

      it 'runs firewalld on nftables with public as catch-all default zone' do
        is_expected.to contain_class('firewalld')
          .with_package_ensure('installed')
          .with_service_ensure('running')
          .with_service_enable(true)
          .with_default_zone('public')
          .with_firewall_backend('nftables')
      end

      it 'empties the unused built-in zones' do
        %w[drop dmz home work external].each do |zone|
          is_expected.to contain_firewalld_zone(zone).with_interfaces([]).with_sources([])
        end
      end

      it 'assigns only real public interfaces to the block zone with masquerade' do
        is_expected.to contain_firewalld_zone('block')
          .with_masquerade(true)
          .with_interfaces(['eth0'])
      end

      it 'keeps the default public zone without interfaces' do
        is_expected.to contain_firewalld_zone('public').with_interfaces([])
      end

      it 'trusts tailscale interfaces and the headscale CIDR in the internal zone' do
        is_expected.to contain_firewalld_zone('internal')
          .with_target('ACCEPT')
          .with_interfaces(['tailscale0'])
          .with_sources(['100.64.0.0/10'])
      end

      it 'puts loopback in the trusted zone' do
        is_expected.to contain_firewalld_zone('trusted').with_interfaces(['lo'])
      end

      it 'opens SSH on public, internal, and trusted paths' do
        is_expected.to contain_firewalld_service('Allow SSH - public').with_zone('block').with_service('ssh')
        is_expected.to contain_firewalld_service('Allow SSH - internal').with_zone('internal').with_service('ssh')
        is_expected.to contain_firewalld_service('Allow SSH - trusted').with_zone('trusted').with_service('ssh')
      end

      it 'opens tailscale wireguard on the public zone' do
        is_expected.to contain_firewalld_port('Allow Tailscale WireGuard - public')
          .with_zone('block')
          .with_port('41641')
          .with_protocol('udp')
      end

      it 'allows ICMP from VPN peers' do
        is_expected.to contain_firewalld_rich_rule('Allow ICMP - internal')
          .with_zone('internal')
          .with_protocol('icmp')
          .with_action('accept')
      end
    end
  end
end
