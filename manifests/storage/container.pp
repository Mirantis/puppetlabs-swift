class swift::storage::container(
  $swift_zone,
  $package_ensure = 'present'
) {
  swift::storage::generic { 'container':
    package_ensure => $package_ensure
  }

  # Not tested in other distros, safety measure
  if $operatingsystem == 'Ubuntu' {
    service { 'swift-container-updater':
      ensure    => running,
      enable    => true,
      provider  => $::swift::params::service_provider,
      require   => Package['swift-container'],
    }
    service { 'swift-container-auditor':
      ensure    => running,
      enable    => true,
      provider  => $::swift::params::service_provider,
      require   => Package['swift-container'],
    }
    # The following service conf is missing in Ubunty 12.04
    file { '/etc/init/swift-container-sync.conf':
      source  => 'puppet:///modules/swift/swift-container-sync.conf.upstart',
      require => Package['swift-container'],
    }
    service { 'swift-container-sync':
      ensure    => running,
      enable    => true,
      provider  => $::swift::params::service_provider,
      require   => File['/etc/init/swift-container-sync.conf']
    }
  }
  
  @@ring_container_device { "${swift_local_net_ip}:${port}":
    zone => $swift_zone,
    mountpoints => $swift_mountpoints,
  }
}
