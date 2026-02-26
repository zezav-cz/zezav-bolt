# Ping plan to check connectivity and root access on target nodes.
# @param targets The targets to ping.
plan zezav_bolt::ping(
  TargetSpec $targets,
) {
  # Run a combined command to get UID and Username
  $command_results = run_command('echo "$(id -u):$(whoami)"', $targets, _catch_errors => true)

  $results = $command_results.reduce({}) |$memo, $result| {
    $target = $result.target.name

    if $result.ok {
      # Split the output "0:root" into an array
      $output_parts = $result['stdout'].strip.split(':')
      $uid          = $output_parts[0]
      $user         = $output_parts[1]

      $info = {
        'status'   => 'connected',
        'user'     => $user,
        'has_root' => ($uid == '0'),
      }
    } else {
      $info = {
        'status' => 'unreachable',
        'error'  => $result.error.message,
      }
    }

    $memo + { $target => $info }
  }

  return $results
}
