use strict;
use warnings;
use Cinnamon::DSL;
use Cinnamon::Task::Git;
use Cinnamon::Task::Daemontools;

set application => 'suikawiki';
set git_repository => 'git://github.com/suikawiki/suikawiki-driver.git';
set deploy_dir => '/home/wakaba/server/suikawiki';
set daemontools_service_dir => '/service';
set get_daemontools_service_name => sub {
  return sub {
    return sprintf '%s-%s-web', (get 'application'), (get 'server_env');
  };
};
set get_daemontools_log_file_name => sub {
  return sub {
    sprintf '/var/log/app/%s-%s-web/current',
        (get 'application'), (get 'server_env');
  };
};

role L1 => 'iyokan', {
  server_env => 'L1',
  git_branch => 'sw6',
};

task deploy => sub {
  my ($host, @args) = @_;
  remote { sudo '' } $host;
  call 'update', $host, @args;
  call 'setup', $host, @args;
  call 'install', $host, @args;
  call 'restart', $host, @args;
};

task tail => sub {
  my ($host, @args) = @_;
  call 'web:log:tail', $host, @args;
};

task update => sub {
  my ($host, @args) = @_;
  call 'git:update', $host, @args;
  call 'keys:update', $host, @args;
};

task setup => sub {
  my ($host, @args) = @_;
  call 'app:setup', $host, @args;
};

task install => sub {
  my ($host, @args) = @_;
  call 'app:install', $host, @args;
};

task restart => sub {
  my ($host, @args) = @_;
  call 'web:restart', $host, @args;
};

task keys => {
  update => sub {
    my ($host, @args) = @_;
    my $dir = get 'deploy_dir';
    my $env = get 'server_env';
    remote {
      run 'mkdir', '-p', "$dir/local/keys/$env";
    } $host;
    run 'rsync', '-av', "local/keys/$env" => "$host:$dir/local/keys/";
  },
};

task app => {
  setup => sub {
    my ($host, @args) = @_;
    my $dir = get 'deploy_dir';
    my $name = get 'server_env';
    remote {
      run qq{cd \Q$dir\E && make deps server-config SERVER_ENV=$name};
    } $host;
  },
  install => sub {
    my ($host, @args) = @_;
    my $dir = get 'deploy_dir';
    my $name = get 'server_env';
    remote {
      sudo qq{sh -c "cd \Q$dir\E && LANG=C make install-server-config SERVER_ENV=$name"};
    } $host;
  },
}; # app

task web => {
  (define_daemontools_tasks 'web'),
};

1;
