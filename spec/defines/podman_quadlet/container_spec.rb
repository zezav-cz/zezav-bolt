require 'spec_helper'

describe 'podman_quadlet::container' do
  let(:pre_condition) { 'include podman_quadlet' }
  let(:title) { 'myapp' }
  let(:params) { { 'image' => 'docker.io/example/myapp:1.0' } }

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it 'creates a quadlet with name, image, and restart policy' do
        is_expected.to contain_quadlets__quadlet('myapp.container')
          .with_ensure('present')
          .with_active(true)
          .with_mode('0444')
          .with_service_entry('Restart' => 'always')
          .with_install_entry('WantedBy' => 'default.target')
          .with_container_entry(
            'ContainerName' => 'myapp',
            'Image'         => 'docker.io/example/myapp:1.0',
          )
          .that_requires('Class[podman_quadlet]')
      end

      context 'with private ports' do
        let(:params) { super().merge('ports' => ['8080:80', '9.9.9.9:5353:53/udp']) }

        it 'binds every private port to localhost, stripping any given address' do
          is_expected.to contain_quadlets__quadlet('myapp.container')
            .with_container_entry(
              'ContainerName' => 'myapp',
              'Image'         => 'docker.io/example/myapp:1.0',
              'PodmanArgs'    => [
                '--publish 127.0.0.1:8080:80',
                '--publish 127.0.0.1:5353:53/udp',
              ],
            )
        end
      end

      context 'with public ports' do
        let(:params) do
          super().merge(
            'public_ports' => [
              { 'port' => 80, 'container_port' => 8080 },
              { 'port' => 443, 'container_port' => 8443, 'protocol' => 'udp', 'bind_addr' => '203.0.113.5' },
            ],
          )
        end

        it 'publishes on 0.0.0.0 unless a bind address is given' do
          is_expected.to contain_quadlets__quadlet('myapp.container')
            .with_container_entry(
              'ContainerName' => 'myapp',
              'Image'         => 'docker.io/example/myapp:1.0',
              'PodmanArgs'    => [
                '--publish 0.0.0.0:80:8080/tcp',
                '--publish 203.0.113.5:443:8443/udp',
              ],
            )
        end
      end

      context 'with volumes, network, environment, and capabilities' do
        let(:params) do
          super().merge(
            'volumes'      => ['mydata:/data:Z'],
            'network'      => 'appnet',
            'environment'  => { 'TZ' => 'Europe/Prague' },
            'capabilities' => ['NET_ADMIN'],
          )
        end

        it 'maps them into the Container section' do
          is_expected.to contain_quadlets__quadlet('myapp.container')
            .with_container_entry(
              'ContainerName' => 'myapp',
              'Image'         => 'docker.io/example/myapp:1.0',
              'Volume'        => ['mydata:/data:Z'],
              'Network'       => 'appnet',
              'Environment'   => ['TZ=Europe/Prague'],
              'AddCapability' => ['NET_ADMIN'],
            )
        end
      end

      context 'when inactive' do
        let(:params) { super().merge('active' => false) }

        it { is_expected.to contain_quadlets__quadlet('myapp.container').with_active(false) }
      end
    end
  end
end
