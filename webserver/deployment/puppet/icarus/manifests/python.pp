class icarus::python () {
  class { 'python':
    version            => $icarus::python_version,
    manage_pip_package => false,
  }

  python::pyvenv { 'icarus':
    version  => '3.9',
    venv_dir => $icarus::virtualenv,
    owner    => $icarus::app_user,
    group    => $icarus::app_group,
  }

  python::requirements { "${icarus::project_root}/requirements.txt":
    virtualenv  => $icarus::virtualenv,
    owner       => $icarus::app_user,
    group       => $icarus::app_group,
    forceupdate => true,
  }
}
