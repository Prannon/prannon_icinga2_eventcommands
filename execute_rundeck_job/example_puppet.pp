class example_puppet { 
	###THIS CLASS SHOULD BE APPLIED TO ALL MONITORED HOSTS
	###FILE DEFINITION
	file { '/usr/local/bin/execute_rundeck_job.sh':
                ensure  => present,
                owner   => 'icinga',
                group   => 'icinga',
                mode    => '0755',
                source  => 'puppet:///modules/example_puppet/execute_rundeck_job.sh',
        }

	###THE EVENTCOMMAND DEFINITION
        icinga2::object::eventcommand { 'fix_proc_with_puppet':
                ensure  => present,
                command => [
                        '/usr/local/bin/execute_rundeck_job.sh',
                        '-h','$host.name$',
                        '-s','$service.state$',
                        '-t','$service.state_type$',
                        '-a','$service.check_attempt$',
                        '-x','$auth_token$',
                        '-u','$rundeck_url$',
                        '-j','$rundeck_job_uuid$',
                        '-p','$rundeck_project$',
                ],
                target  => '/etc/icinga2/zones.conf',
                vars    => {
                        'auth_token' => 'putrundeckapitokenhere',
                        'rundeck_url' => 'https://put.rundeck.url.here.com',
                        'rundeck_job_uuid' => 'put-rundeck-job-uuid-here',
                        'rundeck_project' => 'PUT.RUNDECK.PROJECTNAME.HERE',
                },
        }

	###THE SERVICE DEFINITION (JUST AN EXAMPLE, PAY ATTENTION TO THE EVENT_COMMAND PARAM)
	icinga2::object::service { "check_proc":
                target                  => "/etc/icinga2/conf.d/services.conf",
                apply                   => "procs_command => config in host.vars.procs",
                assign                  => ["host.vars.client_endpoint"],
                check_command           => "procs",
                check_interval          => "1m",
                retry_interval          => '30s',
                max_check_attempts      => '10',
                command_endpoint        => "host.vars.client_endpoint",
                event_command           => "fix_proc_with_puppet", #this is the part that matters
                vars                    => {
                        'procs_argument' => "config",
                        'procs_critical' => '1:',
                }
        }
}
