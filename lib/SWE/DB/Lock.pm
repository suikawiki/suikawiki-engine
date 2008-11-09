package SWE::DB::Lock;
use strict;

use Fcntl ':flock';

sub new ($) {
  my $self = bless {
    'file_name' => 'lock',
  }, shift;
  return $self;
} # new

sub lock ($) {
  my $self = shift;
  
  open my $file, '>', $self->{file_name} or die "$0: $self->{file_name}: $!";
  flock $file, LOCK_EX;
  $self->{lock} = $file;
} # lock

sub unlock ($) {
  close $_[0]->{lock};
} # unlock

sub DESTROY ($) {
  $_[0]->unlock;
} # DESTROY

1;
