class atomia::nagios::client(
    $username           = "nagios",
    $password           = "nagios",
    $public_ip          = $ipaddress_eth0,
    $atomia_account     = "100001",
    $apache_agent_class = "atomia::nagios::client::apache_agent",
    $atomiadns_master_class = "atomia::nagios::client::atomiadns_master",
    $nameserver_class       = "atomia::nagios::client::nameserver",
    $fsagent_class          = "atomia::nagios::client::fsagent",
    $awstats_class          = "atomia::nagios::client::awstats",
    $domainreg_class        = "atomia::nagios::client::domainreg",
    $internaldns_class      = "atomia::nagios::client::internaldns",
    $active_directory_class = "atomia::nagios::client::active_directory",
    $glusterfs_class        = "atomia::nagios::client::glusterfs",
    $internal_mailserver_class = "atomia::nagios::client::internal_mailserver",
    $atomia_database_class  = "atomia::nagios::client::atomia_database",
    $internal_apps_class = "atomia::nagios::client::internal_apps",
    $public_apps_class = "atomia::nagios::client::public_apps",
) {

  $atomia_domain = hiera('atomia::config::atomia_domain')
  $internal_domain = hiera('atomia::internaldns::zone_name','')
  if $ec2_public_ipv4 {
    $ip_address = $ec2_public_ipv4
  } else {
    $ip_address = $public_ip
  }

	# Deploy on Windows.
	if $operatingsystem == 'windows' {
		class { 'nsclient':
  			allowed_hosts => ["0.0.0.0/0"],
        package_source_location => 'https://github.com/mickem/nscp/releases/download/0.4.4.15',
        package_source => 'NSCP-0.4.4.15-x64.msi',
		}

    case $atomia_role_1 {
      
      'active_directory':   {
          class { "${active_directory_class}": 
            hostgroup => 'windows-all,windows-domain-controllers'
           }
        }
      'active_directory_replica':   {
          class { "${active_directory_class}": 
            hostgroup => 'windows-all,windows-domain-controllers'
           }
        }
        'public_apps': {
           class { "${public_apps_class}": 
            hostgroup => 'windows-all'
           }           
        }   
        'internal_apps': {
           class { "${internal_apps_class}": 
            hostgroup => 'windows-all'
           }           
        }                       
    }       

	} else {
	# Deploy on other OS (Linux)
    package { [
      'nagios-nrpe-server',
  		'libconfig-json-perl',
  		'libdatetime-format-iso8601-perl'
    ]:
        ensure => installed,
    }

    if ! defined(Package['libwww-mechanize-perl']) {
        package { 'libwww-mechanize-perl':
            ensure => installed,
        }
    }

    # Define hostgroups based on custom fact
    case $atomia_role_1 {
        'domainreg':            {
          $hostgroup = 'linux-atomia-agents,linux-all'
          class { "${domainreg_class}": }
        }

        'internaldns':            {
          $hostgroup = 'linux-all'
          class { "${internaldns_class}": }
        }

        'apache_agent': {
          $hostgroup = 'linux-customer-webservers,linux-all'
          class { "${$apache_agent_class}": }
        }

        'atomiadns_master': {
          $hostgroup = 'linux-dns,linux-all'
          class { "${atomiadns_master_class}": }
          class { "${nameserver_class}": }
        }

        'nameserver': {
          $hostgroup = 'linux-dns,linux-all'
          class { "${nameserver_class}": }
        }

        'awstats': {
          $hostgroup = 'linux-atomia-agents,linux-all'
          class { "${awstats_class}": }
        }

        'cronagent':            { $hostgroup = 'linux-atomia-agents,linux-all'}
        'daggre':               { $hostgroup = 'linux-atomia-agents,linux-all'}
        'fsagent':              {
          $hostgroup = 'linux-atomia-agents,linux-all'
          class { "${fsagent_class}":
              account_used_for_checks => $atomia_account
          }
        }
        'nameserver':           { $hostgroup = 'linux-dns,linux-all'}
        'pureftpd':             { $hostgroup = 'linux-ftp-servers,linux-all'}
        'haproxy':              { $hostgroup = 'linux-atomia-agents,linux-all'}
        'iis':                  { $hostgroup = 'linux-atomia-agents,linux-all'}
        'installatron':         { $hostgroup = 'linux-atomia-agents,linux-all'}
        'mailserver':           { $hostgroup = 'linux-atomia-agents,linux-all'}
        'mysql':                { $hostgroup = 'linux-atomia-agents,linux-all'}
        'phpmyadmin':           { $hostgroup = 'linux-atomia-agents,linux-all'}
        'postgresql':           { $hostgroup = 'linux-atomia-agents,linux-all'}
        'glusterfs': {
          $hostgroup = 'linux-all'
          class { "${glusterfs_class}": }
         }
        'glusterfs_replica': {
          $hostgroup = 'linux-all'
          class { "${glusterfs_class}": }
         }
        'internal_mailserver': {
          $hostgroup = 'linux-all'
          class { "${internal_mailserver_class}": }
         }    
        'atomia_database': {
          $hostgroup = 'linux-all'
          class { "${atomia_database_class}": }
         }                      

    }
    if ! defined(Service['nagios-nrpe-server']) {
      service { 'nagios-nrpe-server':
          ensure => running,
          require => Package["nagios-nrpe-server"],
      }
    }

    # Configuration files
    file { '/etc/nagios/nrpe.cfg':
        owner   => 'root',
        group   => 'root',
        mode    => "0644",
        content => template('atomia/nagios/nrpe.cfg.erb'),
        require => Package["nagios-nrpe-server"],
        notify  => Service["nagios-nrpe-server"]
    }
    

    @@nagios_host { "${fqdn}-host" :
        use                 => "generic-host",
        host_name           => $fqdn,
        alias			    => "${atomia_role_1} - ${fqdn}",
        address             => $ip_address,
        target              => "/usr/local/nagios/etc/servers/${hostname}_host.cfg",
        hostgroups          => $hostgroup,
        max_check_attempts  => '5'
    }
 

	if ($atomia_role_1 == "daggre") {
		@@nagios_service { "${fqdn}-daggre":
			host_name				=> $fqdn,
			service_description		=> "Daggre disk space parser",
			check_command			=> "check_nrpe_1arg!check_daggre_ftp",
			use						=> "generic-service",
			target              	=> "/etc/nagios3/conf.d/${hostname}_services.cfg",
		}

        @@nagios_service { "${fqdn}-daggre-weblog":
            host_name               => $fqdn,
            service_description     => "Daggre weblog parser",
            check_command           => "check_nrpe_1arg!check_daggre_weblog",
            use                     => "generic-service",
            target                  => "/etc/nagios3/conf.d/${hostname}_services.cfg",
        }

	}


    if ($atomia_role == "domainreg") {

        @@nagios_service { "${fqdn}-domainreg":
            host_name               => $fqdn,
            service_description     => "Domainreg API .com",
            check_command           => "check_nrpe!check_domainreg!foo.com",
            use                     => "generic-service",
            target                  => "/etc/nagios3/conf.d/${hostname}_services.cfg",
        }
    }

	if !defined(File["/usr/lib/nagios/plugins/atomia"]){
    	file { "/usr/lib/nagios/plugins/atomia":
			source 				=> "puppet:///modules/atomia/nagios/plugins",
			recurse				=> true,
			require             => Package["nagios-nrpe-server"]
		}
	}

	}
}
