# @summary Run puppet in a bolt way interactively
plan zezav_bolt::install (
  Optional[TargetSpec] $targets = undef,
  Boolean              $noop    = false,
) {
  # --- target selection ---
  if $targets {
    $target_spec = get_targets($targets)
  } else {
    $targets_all = get_targets('all')
    $menu_options = $targets_all.map |$t| { $t.name } + ['ALL TARGETS']
    $selection = prompt::menu('Select host to apply', $menu_options)

    $target_spec = if $selection == 'ALL TARGETS' {
      $targets_all
    } else {
      get_targets($selection)
    }
  }

  $mode = if $noop { 'noop' } else { 'apply' }
  $start_time = Timestamp.new()
  $timestamp = $start_time.strftime('%Y%m%d_%H%M%S')
  $node_names = $target_spec.map |$t| { $t.name }.join(', ')

  out::message("=== Puppet ${mode} started at ${start_time} ===")
  out::message("Targets: ${node_names}")

  apply_prep($target_spec)

  $results = apply($target_spec, '_noop' => $noop) {
    include zezav_bolt::nodes
  }

  $end_time = Timestamp.new()
  $duration = $end_time - $start_time

  # --- per-node reporting ---
  $results.each |$result| {
    $node = $result.target.name

    if $result.ok {
      $report = $result.report
      $status = $report['status']

      # Build resource stats hash from metrics
      $res_stats = $report['metrics']['resources']['values'].reduce({}) |$memo, $v| {
        $memo + { $v[0] => $v[2] }
      }

      $header_lines = [
        "--- ${node} [${status}] ---",
        "Resources: ${res_stats['total']} total, ${res_stats['changed']} changed, ${res_stats['failed']} failed, ${res_stats['skipped']} skipped, ${res_stats['out_of_sync']} out-of-sync",
      ]

      $log_lines = $report['logs'].filter |$log| {
        $log['level'] in ['notice', 'warning', 'err']
      }.map |$log| {
        $src = if $log['source'] { " (${log['source']})" } else { '' }
        "${log['level']}: ${log['message']}${src}"
      }

      $all_lines = $header_lines + $log_lines
    } else {
      $all_lines = [
        "--- ${node} [FAILED] ---",
        "Error: ${result.error.message}",
        "Kind: ${result.error.kind}",
      ]
    }

    $all_lines.each |$line| {
      out::message("[${node}] ${line}")
    }

    # Save log with metadata header
    $log_header = [
      "# Puppet ${mode} log for ${node}",
      "# Started: ${start_time}",
      "# Completed: ${end_time}",
      "# Duration: ${duration}",
      '',
    ]
    $log_content = ($log_header + $all_lines).join("\n")

    $log_file = "logs/${node}_${mode}_${timestamp}.log"
    run_task('zezav_bolt::save_log', 'localhost', {
        'path'    => $log_file,
        'content' => $log_content,
    })
    out::message("Log saved to ${log_file}")
  }

  # --- summary ---
  $ok_nodes = $results.filter |$r| { $r.ok }.map |$r| { $r.target.name }
  $fail_nodes = $results.filter |$r| { !$r.ok }.map |$r| { $r.target.name }

  out::message('')
  out::message('=== Summary ===')
  out::message("Mode: ${mode} | Duration: ${duration} | Targets: ${target_spec.length}")
  out::message("Succeeded: ${ok_nodes.length} | Failed: ${fail_nodes.length}")

  if $fail_nodes.length > 0 {
    $fail_list = $fail_nodes.join(', ')
    out::message("Failed nodes: ${fail_list}")
  }

  out::message("=== Finished at ${end_time} ===")

  return $results
}
