# Node classification — maps each server hostname to its set of profiles.
# Unknown nodes trigger a catalog compilation failure.
class zezav_bolt::nodes {
  case $facts['networking']['hostname'] {
    'z01': {
      include profile::base
    }
    'z02': {
      include profile::base
      include profile::podman
    }
    'z03': {
      include profile::base
      include profile::podman
    }
    default: {
      fail("No classification defined for: ${facts['networking']['fqdn']}")
    }
  }
}
