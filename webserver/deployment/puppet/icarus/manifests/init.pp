class icarus (
  String $site_url,
  String $app_user,
  String $virtualenv,
  String $project_root,
  String $secrets_dir,
) {
  $python_version = 'python39'
  $app_root = "${project_root}/icarus"
  $app_group = $app_user

  class { 'selinux':
    mode => 'permissive'
  }

  file { "${app_root}/config.ini":
    ensure => file,
    source => "${secrets_dir}/config.ini",
    owner  => $app_user,
    group  => $app_group,
  }

  class { 'icarus::python': }

  class { 'icarus::apache': }
  ->
  class { 'icarus::shibboleth': }
  ~>
  service { ['httpd.service', 'shibd']:
    ensure => running,
    enable => true,
  }
}
