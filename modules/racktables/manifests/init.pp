# https://racktables.wikimedia.org
## Please note that Racktables is a tarball extraction based installation
## into its web directory root.  This means that puppet cannot fully automate
## the installation at this time & the actual tarball must be downloaded from
## http://racktables.org/ and unzipped into /srv/org/wikimedia/racktables
class racktables (
    $racktables_db_host = 'm1-master.eqiad.wmnet',
    $racktables_db      = 'racktables',
) {

    include mysql
    include passwords::racktables
    include ::apache
    include ::apache::mod::php5
    include ::apache::mod::ssl
    include ::apache::mod::rewrite
    include ::apache::mod::headers

    require_package('php5-mysql', 'php5-gd')

    file { '/srv/org/wikimedia/racktables/wwwroot/inc/secret.php':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => template('racktables/racktables.config.erb'),
    }

    apache::site { 'racktables.wikimedia.org':
        content => template('racktables/racktables.wikimedia.org.erb'),
    }

    # Increase the default memory limit T102092
    file_line { 'racktables_php_memory':
        path    => '/etc/php5/apache2/php.ini',
        line    => 'memory_limit = 256M',
        match   => '^\s*memory_limit',
        require => Class['::apache::mod::php5'],
        notify  => Service['apache2'],
    }
}
