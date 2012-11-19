$swift_master = 'swift-proxy-1'
$swift_proxies = {'swift-proxy-1' => '10.0.0.108', 'swift-proxy-2' => '10.0.0.109' }  
$admin_user           = 'nova'
$admin_password       = 'nova'
$swift_user_password  = 'swift_pass'
$swift_shared_secret  = 'changeme'
$swift_local_net_ip   = $ipaddress_eth0
$swift_proxy_address    = '192.168.1.16'
$swift_api_server = '10.0.0.110'

node swift_base  {
  class { 'swift':
    # not sure how I want to deal with this shared secret
    swift_hash_suffix => 'swift_shared_secret',
    package_ensure    => latest,
  }
 
  class { 'rsync::server':
    use_xinetd => true,
    address    => $swift_local_net_ip,
    use_chroot => 'no',
  }
}
node /swift-storage-1/ inherits swift_base {
  class { role_swift_storage: swift_zone => 1 }
}
node /swift-storage-2/ inherits swift_base {
  class { role_swift_storage: swift_zone => 2 }
}
node /swift-storage-3/ inherits swift_base {
  class { role_swift_storage: swift_zone => 3 }
}
class role_swift_storage($swift_zone) {
  # create xfs partitions on a loopback device and mount them
  swift::storage::loopback { ['dev1', 'dev2']:
    base_dir     => '/srv/loopback-device',
    mnt_base_dir => '/srv/node',
    seek         => '1048756',
    require      => Class['swift'],
  }

  # install all swift storage servers together
  class { 'swift::storage::all':
    storage_local_net_ip => $swift_local_net_ip,
    swift_zone => $swift_zone,
  }

  # collect resources for synchronizing the ring databases
  Swift::Ringsync<<||>>

}

node /swift-proxy/ inherits swift_base {

  # curl is only required so that I can run tests
  package { 'curl': ensure => present }

  include memcached

  # specify swift proxy and all of its middlewares
  class { 'swift::proxy':
    proxy_local_net_ip => $swift_local_net_ip,
    pipeline           => [
      'catch_errors',
      'healthcheck',
      'cache',
      'ratelimit',
      'swift3',
      's3token',
      'authtoken',
      'keystone',
      'proxy-server'
    ],
    account_autocreate => true,
    # TODO where is the  ringbuilder class?
    require            => Class['swift::ringbuilder'],
  }

  # configure all of the middlewares
  class { [
    'swift::proxy::catch_errors',
    'swift::proxy::healthcheck',
    'swift::proxy::swift3',
  ]: }

  $cache_addresses =  inline_template("<%= @swift_proxies.keys.uniq.sort.collect {|ip| ip + ':11211' }.join ',' %>")
  class { 'swift::proxy::cache':
     memcache_servers => split($cache_addresses,',')
  }

  class { 'swift::proxy::ratelimit':
    clock_accuracy         => 1000,
    max_sleep_time_seconds => 60,
    log_sleep_time_seconds => 0,
    rate_buffer_seconds    => 5,
    account_ratelimit      => 0
  }
  class { 'swift::proxy::s3token':
    # assume that the controller host is the swift api server
    auth_host     => $swift_api_server,
    auth_port     => '35357',
  }
  class { 'swift::proxy::keystone':
    operator_roles => ['admin', 'SwiftOperator'],
  }
  class { 'swift::proxy::authtoken':
    admin_user        => $admin_user,
    admin_tenant_name => 'openstack',
    admin_password    => $admin_password,
    # assume that the controller host is the swift api server
    auth_host         => $swift_api_server,
  }

  if $::hostname == $swift_master {
    Class['swift::ringbuilder'] -> Class['swift::proxy']
    # collect all of the resources that are needed
    # to balance the ring
    Ring_object_device <<| |>>
    Ring_container_device <<| |>>
    Ring_account_device <<| |>>
 
    # create the ring
    class { 'swift::ringbuilder':
      # the part power should be determined by assuming 100 partitions per drive
      part_power     => '18',
      replicas       => '3',
      min_part_hours => 1,
      require        => Class['swift'],
    }
    # sets up an rsync db that can be used to sync the ring DB
    class { 'swift::ringserver':
      local_net_ip => $swift_local_net_ip,
    }
    # exports rsync gets that can be used to sync the ring files
    @@swift::ringsync { ['account', 'object', 'container']:
      ring_server => $swift_local_net_ip
    }
 } else {
   Swift::Ringsync<<||>>
   Swift::Ringsync<||> ~> Service["swift-proxy"]
 }

  # deploy a script that can be used for testing
  file { '/tmp/swift_keystone_test.rb':
    source => 'puppet:///modules/swift/swift_keystone_test.rb'
  }
}




