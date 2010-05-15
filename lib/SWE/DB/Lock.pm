package SWE::DB::Lock;
use strict;

my $CurrentlyLocking = {};
my $LockTypes = [qw/
  ID Name Index IDs Names Graph Weight Global
/];
  ## If you are locking for Graph, then you cannot lock for Global, but
  ## still you can lock for ID.
  ##
  ## In addition, if you are locking for an ID, then you can't lock
  ## for another ID.
  ##
  ## XXX Maybe we should get rid of IDs and Name locks because they
  ## conflict with ID and Names locks respectively.  Additionally,
  ## maybe we should remove Global lock as well.

  ## idgen is currently controled by Names lock.

use Fcntl ':flock';

sub new ($) {
  my $self = bless {
    'file_name' => 'lock',
    lock_type => 'Global',
  }, shift;
  return $self;
} # new

sub lock_type ($;$) {
  my $self = shift;
  if (@_) {
    $self->{lock_type} = shift;
  }
  return $self->{lock_type};
} # lock_type

sub check_lockability ($) {
  my $self = shift;
  
  my $self_lt = $self->lock_type;
  for my $lt (@$LockTypes) {
    if ($CurrentlyLocking->{$lt}) {
      die qq[$0: It is currently locking for "$lt" so that it cannot be locked for the "$self_lt"];
    } elsif ($self_lt eq $lt) {
      last;
    }
  }

  return 1;
} # check_lockability
                       
sub lock ($) {
  my $self = shift;

  $self->check_lockability;
  $CurrentlyLocking->{$self->lock_type}++;

  #warn "XXX @{[$self->lock_type]} $CurrentlyLocking->{$self->lock_type} $self->{file_name}";
  
  open my $file, '>', $self->{file_name} or die "$0: $self->{file_name}: $!";
  flock $file, LOCK_EX;
  $self->{lock} = $file;
} # lock

sub unlock ($) {
  my $self = shift;

  $CurrentlyLocking->{$self->lock_type}--;

  close $self->{lock};
} # unlock

sub DESTROY ($) {
  $_[0]->unlock;
} # DESTROY

1;
