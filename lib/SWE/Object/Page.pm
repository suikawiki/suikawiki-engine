package SWE::Object::Page;
use strict;
use warnings;

sub new ($%) {
  my $class = shift;
  my $self = bless {@_}, $class;

  return $self;
}

sub db ($) { $_[0]->{db} }

sub name ($) {
  return $_[0]->{name};
}

1;
