class jira_example (
  $jira_user = 'jira',
  $super_user = 'root',
  $jira_blackout_path = '/pkg/smart/bin/blackout',
  $srv_server = 'server.company.foo',
  $catalina_home = '/opt/catalina',
  $catalina_webapps = "${catalina_home}/webapps",
  $jira_root = '/opt/jira',
  $jira_version = '1.5',
  $jira_staging = "${jira_root}/${jira_version}/staging",
  $jira_home = "${jira_root}/${jira_version}/home",
  $jira_jar = "${jira_root}/${jira_version}/jar",
  $jira_plugins = "${jira_home}/plugins",
  $jira_blackout_schedule = 'default',
  $jira_blackout_url = 'https://jira.company.foo/jira',
  $jira_source_url = 'http://atlassian.com/download/jira.war',
  $java_home = '/usr/bin/java',
  $email_notifications = 'False',
  $date_command = 'date -u +"%Y-%m-%dT%H:%M:%SZ"',
) {
  
  # this creates the jira folder structure for us
  # changing $jira_version will create a new folder
  # our .jar is exploded into that
  file { [ $jira_root, $jira_jar, $jira_home, $jira_staging, $jira_plugins ]:
    ensure => directory,
    owner  => $jira_user,
    mode   => 755,
  }

  remote_file { "${jira_staging}/jira.war":
    ensure => present,
    source => $jira_source_url,
  }

  exec { 'extract_jira_war':
    command => "jar -xvf ${jira_staging}/jira.war",
    creates => "${jira_jar}/index",
    cwd     => $jira_jar,
    path    => "/usr/bin:/usr/local/bin:/usr/sbin:/usr/local/sbin:/bin",
  }

  # this is using the transition module to fire off a sanity backup of plugins
  # not needed because we aren't actually deleting the old jira install
  # just linking the 'live' jira folder to the one specified in $jira_version
  exec { 'backup_plugins':
    command      => "tar xcf jira-plugins-`${date_command}`.tar.gz ${jira_plugins}",
    cwd          => $jira_home,
    path         => "/usr/bin:/usr/local/bin:/usr/sbin:/usr/local/sbin:/bin",
    refresh_only => 'True',
    subscribe    => Transition['stop-jira'],
  }

  # lets just isolate jira in a folder per release
  # so we can just link to the version we want
  # and purge old folders if we need to in the future
  file { "${catalina_webapps}/jira":
    ensure => link,
    target => $jira_home,
    notify => Service['jira'],
  }

  transition { 'stop-jira':
    resource   => Service['jira'],
    attributes => {
      ensure   => 'stopped'
    },
    prior_to   => File["${catalina_webapps}/jira"],
  }

  service { 'jira':
    ensure      => running,
    start       => "${catalina_home}/bin/startup.sh",
    stop        => "${catalina_home}/bin/catalina.sh stop 30 -forece",
    status      => "if [ -f "${jira_home}"/catalina.pid ]; then exit 0; fi",
    hassrestart => 'False',
  }




}


