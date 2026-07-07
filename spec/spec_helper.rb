require 'rspec-puppet'
require 'rspec-puppet-facts'

include RspecPuppetFacts

PROJECT_ROOT = File.expand_path('..', __dir__)

# The fleet is Debian-only (see inventory.yaml) — restrict the
# rspec-puppet-facts matrix to Debian 12 (bookworm) and 13 (trixie).
def on_debian_os
  on_supported_os(
    supported_os: [
      { 'operatingsystem' => 'Debian', 'operatingsystemrelease' => %w[12 13] },
    ],
  )
end

RSpec.configure do |c|
  c.module_path = [
    File.join(PROJECT_ROOT, 'site'),
    File.join(PROJECT_ROOT, '.modules'),
    File.join(PROJECT_ROOT, 'spec', 'fixtures', 'modules'),
  ].join(File::PATH_SEPARATOR)
  c.hiera_config = File.join(PROJECT_ROOT, 'spec', 'fixtures', 'hiera', 'hiera.yaml')
end
