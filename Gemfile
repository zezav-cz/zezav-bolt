source "https://rubygems.org"

# Puppet itself comes from openvox (~> 8.0) via openbolt — do not add the
# `puppet` gem alongside it, or two conflicting `puppet` executables ship.
gem 'openfact', '~> 5.3'
gem 'openbolt', '~> 5.3'

gem 'ed25519',      '~> 1.4'
gem 'bcrypt_pbkdf', '~> 1.1'
# Puppet lint and format
group :lint do
  gem 'nkf'
  gem 'r10k',                                   require: false
  gem 'json'
  gem 'pristine'
  gem 'puppet-lint',                            require: false
  gem 'puppet-lint-strict_indent-check',        require: false
  gem 'puppet-lint-manifest_whitespace-check',  require: false
  gem 'puppet-lint-unquoted_string-check',      require: false
  gem 'puppet-lint-leading_zero-check',         require: false
  gem 'puppet-lint-absolute_classname-check',   require: false
  gem 'puppet-lint-trailing_comma-check',       require: false
  gem 'puppet-lint-file_ensure-check',          require: false
  gem 'puppet-lint-legacy_facts-check',         require: false
  gem 'puppet-lint-class_alignment-check',      require: false
  gem 'puppet-lint-param-docs',                 require: false
end

# Unit tests (rspec-puppet catalog specs)
group :test do
  gem 'rspec-puppet',       require: false
  gem 'rspec-puppet-facts', require: false
  gem 'parallel_tests',     require: false
end

