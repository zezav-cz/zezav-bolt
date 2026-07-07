# @summary Alertmanager container with a Telegram receiver
#
# Receives alerts from Prometheus over the observability network and
# forwards them to a Telegram chat. The UI is published on 127.0.0.1
# only — reach it through an SSH tunnel. The bot token lives in
# per-node hiera (plaintext for now — see the secrets TODO).
#
# @param telegram_bot_token
#   Telegram bot API token used to send notifications
# @param telegram_chat_id
#   Telegram chat ID to notify (negative for group chats)
# @param image
#   Container image reference
# @param active
#   Whether to start and enable the container service
# @param port
#   Host port (bound to 127.0.0.1) mapped to container port 9093
class podman_quadlet::container::alertmanager (
  String  $telegram_bot_token,
  Integer $telegram_chat_id,
  String  $image  = 'docker.io/prom/alertmanager:v0.33.0',
  Boolean $active = true,
  Integer $port   = 9093,
) {
  include podman_quadlet::network::observability

  file { '/etc/alertmanager':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # The prom/alertmanager image runs as nobody (65534); the config embeds
  # the bot token, so only that user may read it
  file { '/var/lib/alertmanager':
    ensure => directory,
    owner  => 'nobody',
    group  => 'nogroup',
    mode   => '0750',
  }

  # create template dir
  file { '/etc/alertmanager/templates':
    ensure => directory,
    owner  => 'nobody',
    group  => 'nogroup',
    mode   => '0750',
  }

  $_template_file_path = '/etc/alertmanager/templates/telegram-template.tmpl'

  file { $_template_file_path:
    ensure  => file,
    owner   => 'nobody',
    group   => 'nogroup',
    mode    => '0640',
    content => file('podman_quadlet/container/telegram-template.tmpl'),
    require => File['/etc/alertmanager/templates'],
  }

  file { '/etc/alertmanager/alertmanager.yml':
    ensure  => file,
    owner   => 'nobody',
    group   => 'nogroup',
    mode    => '0600',
    content => epp('podman_quadlet/container/alertmanager.yml.epp', {
        'telegram_bot_token' => $telegram_bot_token,
        'telegram_chat_id'   => $telegram_chat_id,
        'template_file'      => $_template_file_path,
    }),
    require => File['/etc/alertmanager'],
  }

  podman_quadlet::container { 'alertmanager':
    image         => $image,
    active        => $active,
    ports         => ["${port}:9093"],
    network       => 'observability.network',
    volumes       => [
      '/etc/alertmanager:/etc/alertmanager:ro',
      '/var/lib/alertmanager:/alertmanager',
    ],
    unit_settings => { 'Description' => 'Prometheus Alertmanager' },
    require       => [
      Class['podman_quadlet::network::observability'],
      File['/etc/alertmanager/alertmanager.yml'],
      File['/var/lib/alertmanager'],
    ],
  }
}
