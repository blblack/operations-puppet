# == Define: service::uwsgi
#
# service::uwsgi provides a common wrapper for setting up python services
# based on uwsgi on. It is still a WIP
#
# === Parameters
#
# [*port*]
#   Port on which to run the service
#
# [*config*]
#   The individual service's config to use. It must be a hash of
#   key => value pairs, or a YAML-formatted string. Note that the complete
#   configuration will be assembled using the bits given here and common
#   service configuration directives.
#
# [*no_workers*]
#   Number of workers to start. Default: 'ncpu' (i.e. start as many workers as
#   there are CPUs)
#
# [*healthcheck_url*]
#   The url to monitor the service at. 200 OK is the expected
#   answer. If has_spec it true, this is supposed to be the base url
#   for the spec request
#
# [*has_spec*]
#   If the service specifies a swagger spec, use it to thoroughly
#   monitor it
#
# [*repo*]
#   The name of the repo to use for deployment. Default: ${title}/deploy
#
# [*firejail*]
#   Whether to use firejail when starting the service. Default: true.
#   TODO: This is a NOOP still, need to implement
#
# [*local_logging*]
#   Whether to store log entries on the target node as well. Default: true
#
# [*deployment*]
#   What deployment system to use for deploying this service.
#   Options: scap3, fabric
#   Note: this parameter will be removed onces ores.wmflabs.org stops
#         using service::uwsgi
#
# [*deployment_user*]
#   The user that will own the service code. Only applicable when
#   $deployment ='scap3'. Default: $title
#
# [*deployment_manage_user*]
#   Boolean. Whether or not scap::target manages user. Only applicable
#   when $deployment ='scap3'. Default: false

# [*sudo_rules*]
#   An array of string representing sudo rules in the sudoers format that you
#   want the service to have. Default: empty array
#
# === Examples
#
#    service::uwsgi { 'myservice':
#        port   => 8520,
#        config => {
#           'wsgi-file' => "/path/to/wsgi_file"
#           chdir       => "path_to_dir",
#           venv        => "path_to_virtualenv",
#           param1 => 'val1',
#           param2 => $myvar
#        },
#    }
#
define service::uwsgi(
    $port,
    $config                 = undef,
    $no_workers             = $::processorcount,
    $healthcheck_url        = '/_info',
    $has_spec               = false,
    $repo                   = "${title}/deploy",
    $firejail               = true,
    $local_logging          = true,
    $deployment_user        = 'deploy-service',
    $deployment_manage_user = true,
    $deployment             = 'scap3',
    $sudo_rules             = [],
) {
    if $deployment == 'scap3' {
        scap::target { $repo:
            service_name => $title,
            deploy_user  => $deployment_user,
            before       => Uwsgi::App[$title],
            manage_user  => $deployment_manage_user,
            sudo_rules   => $sudo_rules,
        }
    }

    # Import all common configuration
    include service::configuration

    # we do not allow empty names
    unless $title and size($title) > 0 {
        fail('No name for this resource given!')
    }

    # sanity check since a default port cannot be assigned
    unless $port and $port =~ /^\d+$/ {
        fail('Service port must be specified and must be a number!')
    }

    # the local log file name
    $local_logdir = "${service::configuration::log_dir}/${title}"
    $local_logfile = "${local_logdir}/main.log"

    if $local_logging {
        file { $local_logdir:
            ensure => directory,
            owner  => 'www-data',
            group  => 'root',
            mode   => '0755',
            before => Uwsgi::App[$title],
        }
        file { "/etc/logrotate.d/${title}":
            content => template('service/logrotate.erb'),
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
        }
        $local_log_config = {
            logto       => $local_logfile,
        }
    } else {
        $local_log_config = {}
    }

    file { "/etc/${title}":
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    $base_config = {
            plugins     => 'python, python3',
            master      => true,
            http-socket => "0.0.0.0:${port}",
            processes   => $no_workers,
            die-on-term => true,
    }
    $complete_config = deep_merge($base_config, $local_log_config, $config)

    # TODO: firejail for containment. Not used yet, but the idea is to add it
    require_package('firejail')

    uwsgi::app { $title:
        settings => {
            uwsgi => $complete_config,
        }
    }


    # Basic firewall
    ferm::service { $title:
        proto => 'tcp',
        port  => $port,
    }

    if $has_spec {
        # Advanced monitoring
        include service::monitoring

        $monitor_url = "http://${::ipaddress}:${port}${healthcheck_url}"
        nrpe::monitor_service{ "endpoints_${title}":
            description  => "${title} endpoints health",
            nrpe_command => "/usr/local/lib/nagios/plugins/service_checker -t 5 ${::ipaddress} ${monitor_url}",
            subscribe    => File['/usr/local/lib/nagios/plugins/service_checker'],
        }
        # we also support smart-releases
        # TODO: Enable has_autorestart
        service::deployment_script { $name:
            monitor_url     => $monitor_url,
        }
    } else {
        # Basic monitoring
        monitoring::service { $title:
            description   => $title,
            check_command => "check_http_port_url!${port}!${healthcheck_url}",
        }
    }
}
