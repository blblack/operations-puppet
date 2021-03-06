class snapshot::cron::mediaperprojectlists(
    $enable = true,
    $user   = undef,
) {
    include snapshot::dumps::dirs
    include snapshot::cron::wikiqueryskip

    if ($enable) {
        $ensure = 'present'
    }
    else {
        $ensure = 'absent'
    }

    $apachedir = $snapshot::dumps::dirs::apachedir
    $confsdir = "${snapshot::dumps::dirs::wikiqueriesdir}/confs"

    file { '/usr/local/bin/create-media-per-project-lists.sh':
        ensure  => 'present',
        path    => '/usr/local/bin/create-media-per-project-lists.sh',
        mode    => '0755',
        owner   => $user,
        group   => root,
        content => template('snapshot/cron/create-media-per-project-lists.sh.erb'),
    }

    file { "${confsdir}/wq.conf.media":
        ensure  => 'present',
        path    => "${confsdir}/wq.conf.media",
        mode    => '0644',
        owner   => $user,
        group   => root,
        content => template('snapshot/cron/wq.conf.media.erb'),
    }

    cron { 'list-media-per-project':
        ensure      => $ensure,
        environment => 'MAILTO=ops-dumps@wikimedia.org',
        user        => $user,
        command     => '/usr/local/bin/create-media-per-project-lists.sh',
        minute      => '10',
        hour        => '11',
        weekday     => '7',
    }
}
