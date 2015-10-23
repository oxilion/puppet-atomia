class atomia::nagios::client::domainreg (

  ) {

  @@nagios_service { "${fqdn}-domainreg-process-count":
    host_name				       => $fqdn,
    service_description	  => "Total processes",
    check_command			    => "check_nrpe!check_total_procs",
    use						        => "generic-service",
    target              	=> "/usr/local/nagios/etc/servers/${hostname}_service.cfg",
    owner                 => "nagios"
  }


  @@nagios_service { "${fqdn}-domainreg":
      host_name               => $fqdn,
      service_description     => "Domainreg API .com",
      check_command           => "check_nrpe!check_domainreg!foo.com",
      use                     => "generic-service",
      target              	=> "/usr/local/nagios/etc/servers/${hostname}_service.cfg",
      owner                 => "nagios"
  }

}
