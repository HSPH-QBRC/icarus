class icarus::shibboleth::install () {
  file { '/etc/yum.repos.d/shibboleth.repo':
    ensure => file,
    source => "puppet:///modules/icarus/shibboleth.repo",
  }
  ->
  package { 'shibboleth': }
}
