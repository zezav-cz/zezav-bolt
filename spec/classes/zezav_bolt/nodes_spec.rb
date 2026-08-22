require 'spec_helper'

describe 'zezav_bolt::nodes' do
  def facts_for_host(os_facts, hostname)
    os_facts.merge(
      networking: os_facts[:networking].merge(
        'hostname' => hostname,
        'fqdn'     => "#{hostname}.de.zezav.cz",
      ),
    )
  end

  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      context 'as z01' do
        let(:facts) { facts_for_host(os_facts, 'z01') }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('profile::base') }
        it { is_expected.not_to contain_class('profile::podman') }
      end

      %w[z02 z03].each do |host|
        context "as #{host}" do
          let(:facts) { facts_for_host(os_facts, host) }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('profile::base') }
          it { is_expected.to contain_class('profile::podman') }
        end
      end

      context 'as an unknown node' do
        let(:facts) { facts_for_host(os_facts, 'rogue') }

        it 'refuses to compile' do
          is_expected.to compile.and_raise_error(%r{No classification defined for: rogue\.de\.zezav\.cz})
        end
      end
    end
  end
end
