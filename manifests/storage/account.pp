class swift::storage::account(
  $swift_zone,
  $package_ensure = 'present'
) {
  swift::storage::generic { 'account':
    package_ensure => $package_ensure,
  }

  # Not tested in other distros, safety measure
  if $operatingsystem == 'Ubuntu' {
    service { 'swift-account-reaper':
      ensure    => running,
      enable    => true,
      provider  => $::swift::params::service_provider,
      require   => Package['swift-account'],
    }

    service { 'swift-account-auditor':
      ensure    => running,
      enable    => true,
      provider  => $::swift::params::service_provider,
      require   => Package['swift-account'],
    }
  }

  @@ring_account_device { "${swift_local_net_ip}:${port}":
    zone => $swift_zone,
    mountpoints => $swift_mountpoints,
  }
}
