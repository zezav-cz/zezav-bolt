# Sets up certbot for Let's Encrypt certificate management.
#
# @param email
#   Email address for certbot registration and renewal notifications
# @param key_type
#   Key type for certificates
# @param nginx
#   Whether to include the nginx certbot plugin
class profile::certbot (
  String               $email,
  Enum['ecdsa', 'rsa'] $key_type = 'ecdsa',
  Boolean              $nginx    = true,
) {
  class { 'letsencrypt' :
    email             => $email,
    key_type          => $key_type,
    renew_cron_ensure => 'present',
    renew_cron_hour   => 18,
    cron_scripts_path => '/var/lib/letsencrypt-puppet',
    # Ensure config_dir is also absolute if it's causing issues
    config_dir        => '/etc/letsencrypt',
  }
  if $nginx {
    include letsencrypt::plugin::nginx
  }
}
