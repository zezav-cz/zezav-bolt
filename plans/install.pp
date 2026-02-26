# Install plan to set up Puppet agent and apply base profile.
# @param targets The targets to install Puppet on.
plan zezav_bolt::install (
  TargetSpec $targets,
) {
  # Install Puppet agent on target nodes
  apply_prep($targets)

  # Apply profile::base which includes motd
  apply($targets) {
    include profile::base
  }
}
