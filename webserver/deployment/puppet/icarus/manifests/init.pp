class icarus (
  String $site_url,
  String $app_user,
  String $virtualenv,
  String $project_root,
) {
  $python_version = 'python39'
  $app_root = "${project_root}/icarus"
  $app_group = $app_user

  class { 'selinux':
    mode => 'disabled'
  }

  class { 'icarus::shibboleth': }
  class { 'icarus::python': }
  class { 'icarus::apache': }
}
