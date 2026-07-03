# @summary Enables fail2ban intrusion prevention.
#
# NOTE: not yet classified anywhere, and the fail2ban module it includes is
# not in bolt-project.yaml — add the module pin before including this class.
# Tracked in TODO.md.
class profile::fail2ban {
  include fail2ban
}
