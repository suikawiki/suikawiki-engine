package SWE::Warabe::App;
use strict;
use warnings;
use Warabe::App;
push our @ISA, qw(Warabe::App);

sub config ($;$) {
  if (@_ > 1) {
    $_[0]->{config} = $_[1];
  }
  return $_[0]->{config};
} # config

1;
