class icarus::shibboleth () {
  file { '/etc/yum.repos.d/shibboleth.repo':
    ensure => file,
    source => "puppet:///modules/icarus/shibboleth.repo",
  }
  package { 'shibboleth':
    require => [
      File['/etc/yum.repos.d/shibboleth.repo'],
      Class['icarus::apache'],
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
    source => "puppet:///modules/icarus/prod-idp-metadata.xml",
  }
  file { '/etc/shibboleth/attribute-map.xml':
    ensure => file,
    source => "puppet:///modules/icarus/attribute-map.xml",
  }
  file { '/etc/shibboleth/shibboleth2.xml':
    ensure => file,
    source => "puppet:///modules/icarus/shibboleth2.xml",
  }
  file { '/etc/shibboleth/sp-encrypt-cert.pem':
    ensure => file,
    source => "${icarus::project_root}/secrets/sp-encrypt-cert.pem",
    owner  => 'shibd',
    group  => 'shibd',
  }
  file { '/etc/shibboleth/sp-encrypt-key.pem':
    ensure => file,
    source => "${icarus::project_root}/secrets/sp-encrypt-key.pem",
    owner  => 'shibd',
    group  => 'shibd',
    mode   => '0600',
  }
  file { '/etc/shibboleth/sp-signing-cert.pem':
    ensure => file,
    source => "${icarus::project_root}/secrets/sp-signing-cert.pem",
    owner  => 'shibd',
    group  => 'shibd',
  }
  file { '/etc/shibboleth/sp-signing-key.pem':
    ensure => file,
    source => "${icarus::project_root}/secrets/sp-signing-key.pem",
    owner  => 'shibd',
    group  => 'shibd',
    mode   => '0600',
  }
}
