# @summary Prometheus node_exporter, part of the base profile.
#
# Thin wrapper around monitoring::node_exporter so every node exposes
# host metrics; the version is tunable via the
# `monitoring::node_exporter::version` hiera key.
class profile::node_exporter {
  include monitoring::node_exporter
}
