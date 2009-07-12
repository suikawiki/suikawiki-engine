package SWE::DB::IDLocks;
use strict;

require SWE::DB::IDProps;
push our @ISA, 'SWE::DB::IDProps';

require SWE::DB::Lock;

sub new ($) {
  my $self = shift->SUPER::new (@_);
  $self->{leaf_suffix} = '.lock';
  return $self;
} # new

sub get_lock ($$) {
  my $self = shift;
  my $file_name = $self->_get_file_name ($_[0], 1);

  my $lock = SWE::DB::Lock->new;
  $lock->{file_name} = $file_name;
  $lock->lock_type ('ID');

  return $lock;
} # get_lock

1;
