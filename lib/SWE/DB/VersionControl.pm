package SWE::DB::VersionControl;
use strict;
use Path::Tiny;

sub new_from_root_path ($$) {
  my ($class, $root_path) = @_;
  return bless {root_path => $root_path,
                added_directories => {},
                added_files => {},
                modified_files => {}}, $class;
} # new_from_root_path

sub root_path ($) {
  return $_[0]->{root_path};
} # root_path

sub _init {
  my $self = $_[0];
  my $dir_path = $self->root_path;
  $dir_path->mkpath unless $dir_path->exists;
  unless ($dir_path->child ('.git')->exists) {
    (system "cd \Q$dir_path\E && git init") == 0 or die $?;
  }

  unless ($dir_path->child ('.gitconfig')->exists) {
    (system "git config --file $dir_path/.gitconfig user.name wiki") == 0 or die $?;
    (system "git config --file $dir_path/.gitconfig user.email wiki\@suikawiki.org") == 0 or die $?;
    $self->add_file ($dir_path->child (".gitconfig"));
  }

  my $ignore_path = $dir_path->child ('.gitignore');
  my @ignore;
  push @ignore, split /\x0D?\x0A/, $ignore_path->slurp if $ignore_path->is_file;
  push @ignore, qw(
    *.lock
    *.htmlcache
    *.domcache
    *.cacheprops
    *.tfidf
    *.x
    /names/*/*/*.hi
  );
  my %found;
  @ignore = grep { length $_ and not $found{$_}++ } @ignore;
  $ignore_path->spew (join "\x0A", @ignore);
  $self->add_file ($ignore_path);
} # _init

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
  $self->_init;

  #for (sort {$a cmp $b} keys %{$self->{added_directories}}) {
  #  add directory $_;
  #}

  my @file = (keys %{$self->{added_files}}, keys %{$self->{modified_files}});
  if (@file) {
    my $dir_path = $self->root_path;
    local $ENV{HOME} = ''.$dir_path->absolute;
    my $loop = 0;
    while (1) {
      my $r = (system "cd \Q$dir_path\E && " . join ' ', map { quotemeta $_ } 'git', 'add', map { path ($_)->relative ($dir_path) } @file);
      #system "cd \Q$dir_path\E && git commit -m \Q$msg\E";
      if ($r == 0) {
        last;
      } else {
        die $? if $loop++ > 20;
      }
      sleep 10;
    }
  }
} # commit_changes

1;

=head1 LICENSE

Copyright 2002-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
