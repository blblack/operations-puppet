define aptly::repo (
    $distribution = $title,
    $component = 'main',
    $publish = false,
) {
    require ::aptly

    $repo_name = "${title}-${component}"
    exec { "create-aptly-repo-${title}":
        command => "/usr/bin/aptly repo create -component=${component} -distribution=${distribution} ${repo_name}",
        unless  => "/usr/bin/aptly repo show ${repo_name} > /dev/null",
        user    => 'root',
    }

    if $publish {
        # Pubish the repo directly, without snapshots
        # This isn't reccomended by aptly for production uses, but is perfect for labs :D
        exec { "publish-aptly-repo-${title}":
            command => "/usr/bin/aptly -architectures=amd64,all publish -skip-signing repo ${repo_name}",
            unless  => "/usr/bin/aptly publish list | /bin/grep -F '[${repo_name}]' > /dev/null",
            user    => 'root',
            require => Exec["create-aptly-repo-${title}"],
        }
    }
}
