node default {
  class { 'icarus':
    site_url     => $facts['site_url'],
    app_user     => $facts['app_user'],
    virtualenv   => $facts['virtualenv'],
    project_root => $facts['project_root'],
    secrets_dir  => $facts['secrets_dir'],
  }
}
