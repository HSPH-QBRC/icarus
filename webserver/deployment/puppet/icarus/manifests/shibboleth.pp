class icarus::shibboleth () {
  file { '/etc/yum.repos.d/shibboleth.repo':
    ensure => file,
    source => "puppet:///modules/icarus/shibboleth.repo",
  }
  ->
  package { 'shibboleth': }
  ->
  class { 'icarus::shibboleth::config': }
}

class icarus::shibboleth::config () {
  $shib_conf_dir = "/etc/shibboleth"

  file { "${shib_conf_dir}/prod-idp-metadata.xml":
    ensure => file,
    source => 'puppet:///modules/icarus/prod-idp-metadata.xml',
  }
  file { "${shib_conf_dir}/attribute-map.xml":
    ensure => file,
    source => 'puppet:///modules/icarus/attribute-map.xml',
  }
  file { "${shib_conf_dir}/shibboleth2.xml":
    ensure => file,
    source => 'puppet:///modules/icarus/shibboleth2.xml',
  }

  file { "${shib_conf_dir}/sp-encrypt-cert.pem":
    ensure => file,
    source => "${icarus::secrets_dir}/sp-encrypt-cert.pem",
    owner  => 'shibd',
    group  => 'shibd',
  }
  file { "${shib_conf_dir}/sp-encrypt-key.pem":
    ensure => file,
    source => "${icarus::secrets_dir}/sp-encrypt-key.pem",
    owner  => 'shibd',
    group  => 'shibd',
    mode   => '0600',
  }
  file { "${shib_conf_dir}/sp-signing-cert.pem":
    ensure => file,
    source => "${icarus::secrets_dir}/sp-signing-cert.pem",
    owner  => 'shibd',
    group  => 'shibd',
  }
  file { "${shib_conf_dir}/sp-signing-key.pem":
    ensure => file,
    source => "${icarus::secrets_dir}/sp-signing-key.pem",
    owner  => 'shibd',
    group  => 'shibd',
    mode   => '0600',
  }

  # for convenience
  file { '/var/log/shibboleth':
    mode => 'o+rx',
  }
}
