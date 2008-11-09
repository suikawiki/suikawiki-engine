package SWE::DB::VersionControl;
use strict;

sub new ($) {
  my $self = bless {
    added_directories => {},
    added_files => {},
    modified_files => {},
  }, shift;
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

sub write_file ($$) {
  my $self = shift;
  my $file_name = shift;
  $self->{modified_files}->{$file_name} = 1;
} # write_file

sub commit_changes ($$) {
  my $self = shift;
  my $msg = shift;

  for (sort {$a cmp $b} keys %{$self->{added_directories}}) {
    _system ('cvs', 'add', $_);
  }

  for (keys %{$self->{added_files}}) {
    _system ('cvs', 'add', $_);
  }
  
  my @changed;
  for (keys %{$self->{modified_files}}) {
    push @changed, $_;
  }       
       
  if (@changed) {
    _system ('cvs', 'ci', -m => $msg, @changed)
        or die "$0: commit_changes: $?";
  }
} # commit_changes

sub _system (@) {
  return ((system join (' ', map {quotemeta $_} @_) . " > /dev/null") == 0);
  ## If false, see $? for exit value of the program.
  ## TODO: If false, log the stdout/stderr...
} # _system


1;
