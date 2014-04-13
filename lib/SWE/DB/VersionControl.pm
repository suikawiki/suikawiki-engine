package SWE::DB::VersionControl;
use strict;
use Path::Tiny;

sub new ($%) {
  my ($class, %args) = @_;
  my $self = bless {
    db_dir_name => $args{db_dir_name},
    added_directories => {},
    added_files => {},
    modified_files => {},
  }, $class;
  unless (-d $args{db_dir_name}) {
    path ($args{db_dir_name})->mkpath;
    unless (-d "$args{db_dir_name}/.git") {
      system "cd \Q$args{db_dir_name}\E && git init";
      # XXX if error,
    }
  }
  return $self;
} # new

sub add_directory ($$) {
  my $self = shift;
  my $directory_name = shift;
  $self->{added_directories}->{$directory_name} = 1;
} # add_directory

sub add_file ($$) {
  my $self = shift;
  my $file_name = shift;
  $self->{added_files}->{$file_name} = 1;
  $self->{modified_files}->{$file_name} = 1;
} # add_file

## TODO: remove_file

sub write_file ($$) {
  my $self = shift;
  my $file_name = shift;
  $self->{modified_files}->{$file_name} = 1;
} # write_file

sub commit_changes ($$) {
  my $self = shift;
  my $msg = shift;

  #for (sort {$a cmp $b} keys %{$self->{added_directories}}) {
  #  add directory $_;
  #}

  my @file = (keys %{$self->{added_files}}, keys %{$self->{modified_files}});
  if (@file) {
    my $dir_path = path ($self->{db_dir_name});
    system "cd \Q$dir_path\E && " . join ' ', map { quotemeta $_ } 'git', 'add', map { path ($_)->relative ($dir_path) } @file;
    # XXX if error,

    system "cd \Q$dir_path\E && git commit -m \Q$msg\E";
    # XXX if error,
  }
} # commit_changes

1;
