# Manages node_exporter binary installation
#
# @param version
#   The version of node_exporter to install
# @param checksum_verify
#   Whether to verify the checksum of the downloaded binary
# @param checksum
#   Optional SHA256 checksum for the downloaded file. If not provided and checksum_verify is true, will be looked up from hiera
# @param filename
#   Optional custom filename for the archive. If not provided, will be auto-generated based on version and platform
class monitoring::binary::node_exporter (
  String           $version         = '1.10.2',
  Boolean          $checksum_verify = true,
  Optional[String] $checksum        = undef,
  Optional[String] $filename        = undef,
) {
  $_base_path = '/opt/monitoring/node_exporter'
  $_filename = $filename ? {
    undef   => "node_exporter-${version}.${downcase($facts['kernel'])}-${facts['os']['architecture']}.tar.gz",
    default => $filename,
  }
  $_source_url = "https://github.com/prometheus/node_exporter/releases/download/v${version}/${_filename}"
  $_extracted_dirname = "node_exporter-${version}.${downcase($facts['kernel'])}-${facts['os']['architecture']}"
  $_created_binary_path = "${_base_path}/${_extracted_dirname}/node_exporter"

  if $checksum_verify and $checksum == undef {
    $_hash_sum = lookup('monitoring::node_exporter_checksums', { 'default_value' => {} }).dig($version, $_filename)
    if $_hash_sum == undef {
      fail("Checksum for node_exporter version ${version} and file ${_filename} not found in hiera (lookup key: monitoring::node_exporter_checksums).")
    }
  } else {
    $_hash_sum = $checksum
  }

  file { '/opt/monitoring':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
  -> file { $_base_path:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
  -> archive { "${_base_path}/${_filename}":
    ensure        => present,
    extract       => true,
    extract_path  => $_base_path,
    source        => $_source_url,
    checksum      => $checksum_verify ? { true => $_hash_sum, default => undef },
    checksum_type => 'sha256',
    creates       => $_created_binary_path,
    cleanup       => false,
    require       => File[$_base_path],
  }
  -> file { '/usr/local/bin/node_exporter':
    ensure => link,
    target => $_created_binary_path,
  }
}
