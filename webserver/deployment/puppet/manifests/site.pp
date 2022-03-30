node default {
  $app_user = 'vagrant'
  $app_group = $app_user
  $python_version = 'python39'
  $site_url = 'localhost:8080'
  $virtualenv = '/home/vagrant/venv'
  $project_root = '/vagrant'
  $app_root = "${project_root}/icarus"

  class { 'selinux':
    mode => 'disabled'
  }

  file { '/etc/yum.repos.d/shibboleth.repo':
    ensure => file,
    source => "${project_root}/deployment/puppet/templates/shibboleth.repo",
  }
  package { 'shibboleth':
    require => [
      File['/etc/yum.repos.d/shibboleth.repo'],
      Class['Apache'],
    ],
    before  => [
      File['/etc/shibboleth/prod-idp-metadata.xml'],
      File['/etc/shibboleth/attribute-map.xml'],
      File['/etc/shibboleth/shibboleth2.xml'],
      File['/etc/shibboleth/sp-encrypt-cert.pem'],
      File['/etc/shibboleth/sp-encrypt-key.pem'],
      File['/etc/shibboleth/sp-signing-cert.pem'],
      File['/etc/shibboleth/sp-signing-key.pem'],
    ]
  }
  file { '/etc/shibboleth/prod-idp-metadata.xml':
    ensure => file,
    source => "${project_root}/deployment/puppet/templates/prod-idp-metadata.xml",
  }
  file { '/etc/shibboleth/attribute-map.xml':
    ensure => file,
    source => "${project_root}/deployment/puppet/templates/attribute-map.xml",
  }
  file { '/etc/shibboleth/shibboleth2.xml':
    ensure => file,
    source => "${project_root}/deployment/puppet/templates/shibboleth2.xml",
  }
  file { '/etc/shibboleth/sp-encrypt-cert.pem':
    ensure => file,
    source => "${project_root}/secrets/sp-encrypt-cert.pem",
    owner  => 'shibd',
    group  => 'shibd',
  }
  file { '/etc/shibboleth/sp-encrypt-key.pem':
    ensure => file,
    source => "${project_root}/secrets/sp-encrypt-key.pem",
    owner  => 'shibd',
    group  => 'shibd',
    mode   => '0600',
  }
  file { '/etc/shibboleth/sp-signing-cert.pem':
    ensure => file,
    source => "${project_root}/secrets/sp-signing-cert.pem",
    owner  => 'shibd',
    group  => 'shibd',
  }
  file { '/etc/shibboleth/sp-signing-key.pem':
    ensure => file,
    source => "${project_root}/secrets/sp-signing-key.pem",
    owner  => 'shibd',
    group  => 'shibd',
    mode   => '0600',
  }

  class { 'python':
    version            => $python_version,
    manage_pip_package => false,
  }
  python::pyvenv { 'icarus':
    version  => '3.9',
    venv_dir => $virtualenv,
    owner    => $app_user,
    group    => $app_group,
  }
  python::requirements { "${project_root}/requirements.txt":
    virtualenv  => $virtualenv,
    owner       => $app_user,
    group       => $app_group,
    forceupdate => true,
  }

  class { 'apache': }
  class { 'apache::mod::wsgi':
    package_name => "${python_version}-mod_wsgi",
    mod_path     => 'mod_wsgi_python3.so',
  }
  apache::vhost { 'icarus':
    servername                   => $site_url,
    vhost_name                   => '*',
    port                         => 80,
    docroot                      => false,
    directories                  => [
      { path => "${app_root}" },
    ],
    wsgi_script_aliases          => { '/' => "${app_root}/wsgi.py" },
    wsgi_daemon_process          => {
      'icarus' => {
        user        => $app_user,
        group       => $app_group,
        python-home => $virtualenv,
        python-path => $app_root,
      }
    },
    wsgi_process_group           => 'icarus',
    # to avoid warnings about using the $name parameter for log and config file names
    # https://github.com/puppetlabs/puppetlabs-apache/blob/main/manifests/vhost.pp#L2139
    use_servername_for_filenames => true,
    use_port_for_filenames       => true,
  }
}
