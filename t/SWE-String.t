use strict;
use warnings;
use utf8;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use SWE::String;
use Test::X1;
use Test::More;
use Test::Differences;

test {
  my $c = shift;
  my %terms;
  for_unique_words {
    $terms{$_[0]} = $_[1];
  } q{};
  eq_or_diff [sort { $a cmp $b } keys %terms], [];
  ok $terms{$_} for keys %terms;
  done $c;
} n => 1 + 0, name => 'for_unique_words empty';

test {
  my $c = shift;
  my %terms;
  for_unique_words {
    $terms{$_[0]} = $_[1];
  } q{私は眠いです。};
  eq_or_diff [sort { $a cmp $b } keys %terms],
             [qw(。 です は 眠い 私)];
  ok $terms{$_} for keys %terms;
  done $c;
} n => 1 + 5, name => 'for_unique_words';

test {
  my $c = shift;
  my %terms;
  for_unique_words {
    $terms{$_[0]} = $_[1];
  } q{This is a pen, Mr. Foo!};
  eq_or_diff [sort { $a cmp $b } keys %terms],
             [qw(! , . a foo is mr pen this)];
  ok $terms{$_} for keys %terms;
  done $c;
} n => 1 + 9, name => 'for_unique_words';

run_tests;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
