class icarus::apache () {
  class { 'apache': }

  class { 'apache::mod::wsgi':
    package_name => "${icarus::python_version}-mod_wsgi",
    mod_path     => 'mod_wsgi_python3.so',
  }

  apache::vhost { 'icarus':
    servername                   => $icarus::site_url,
    vhost_name                   => '*',
    port                         => 80,
    docroot                      => false,
    directories                  => [
      {
        path => $icarus::app_root
      },
      {
        path       => '/Shibboleth.sso',
        provider   => 'location',
        sethandler => 'shib',
      }
    ],
    wsgi_script_aliases          => { '/' => "${icarus::app_root}/wsgi.py" },
    wsgi_daemon_process          => {
      'icarus' => {
        user        => $icarus::app_user,
        group       => $icarus::app_group,
        python-home => $icarus::virtualenv,
        python-path => $icarus::app_root,
      }
    },
    wsgi_process_group           => 'icarus',
    # to avoid warnings about using the $name parameter for log and config file names
    # https://github.com/puppetlabs/puppetlabs-apache/blob/main/manifests/vhost.pp#L2139
    use_servername_for_filenames => true,
    use_port_for_filenames       => true,
  }
}
