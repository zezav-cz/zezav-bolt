# Manages POSIX ACLs for specified paths
#
# @param paths
#   Hash of absolute paths to their ACL configuration. Each path requires 'permission' array and optional 'action', 'ignore_missing', 'recursemode', and 'recursive' settings
class profile::posix_acl (
  Hash[Stdlib::AbsolutePath, Struct[{
        'permission' => Array[String,1],
        'action' => Optional[Enum['set', 'unset', 'exact', 'purge']],
        'ignore_missing' => Optional[Enum['false', 'quiet', 'notify']],
        'recursemode' => Optional[Enum['lazy', 'deep']],
        'recursive' => Optional[Boolean],
  }]] $paths = {},
) {
  if empty($paths) {
    warning('No POSIX ACLs to manage')
  } else {
    $paths.each |$path, $params| {
      # TODO add catch for file and test drift
      posix_acl { $path:
        permission     => $params['permission'],
        action         => $params['action'],
        ignore_missing => $params['ignore_missing'],
        recursemode    => $params['recursemode'],
        recursive      => $params['recursive'],
      }
    }
  }
}
