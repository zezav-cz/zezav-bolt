source "https://rubygems.org"

gem 'puppet', '~> 8.10.0'
gem 'openfact', '~> 5.3'
gem 'openbolt', '~> 5.3'

gem 'ed25519',      '~> 1.4'
gem 'bcrypt_pbkdf', '~> 1.1'
# Puppet lint and format
group :lint do
  gem 'nkf'
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

