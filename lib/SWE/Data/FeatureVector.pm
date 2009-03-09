package SWE::Data::FeatureVector;
use strict;
use warnings;

sub new ($) {
  my $self = bless {t => {}}, shift;
  return $self;
} # new

sub parse_stringref ($$) {
  my $self = shift->new;
  my $sref = $_[0] || \'';
  
  $self->{t} = { map { split /\t/, $_, 2 } split /[\x0D\x0A]+/, $$sref };
  
  return $self;
} # parse_stringref

sub set_tfidf ($$$) {
  #my ($self, $term, $tfidf) = @_;
  $_[0]->{t}->{$_[1]} = $_[2];
} # set_tfidf

sub as_key_hashref ($) {
  my $self = shift;
  return {map {$_ => 1} keys %{$self->{t}}};
} # as_key_hashref

sub clone ($) {
  my $self = shift;
  my $clone = ref ($self)->new;
  $clone->{t} = {%{$self->{t}}};
  return $clone;
} # clone

sub add ($$) {
  my $a = shift;
  my $b = shift;
  
  my $r = $a->clone;

  no warnings 'uninitialized';
  for (keys %{$b->{t}}) {
    $r->{t}->{$_} += $b->{t}->{$_};
  }
  
  return $r;
} # add

sub subtract ($$) {
  my $a = shift;
  my $b = shift;
  
  my $r = $a->clone;

  no warnings 'uninitialized';
  for (keys %{$b->{t}}) {
    $r->{t}->{$_} -= $b->{t}->{$_};
  }
  
  return $r;
} # subtract

sub multiply ($$) {
  my $a = shift;
  my $b = shift;
  
  my $r = $a->clone;
  
  no warnings 'uninitialized';
  for (keys %{$a->{t}}) { # $a, not $r
    $r->{t}->{$_} *= $b->{t}->{$_};
    delete $r->{t}->{$_} if $r->{t}->{$_} == 0;
  }

  return $r;
} # multiply

sub component_sum ($) {
  my $self = shift;
  my $r = 0;

  for (keys %{$self->{t}}) {
    $r += $self->{t}->{$_};
  }
  
  return $r;
} # component_sum

sub stringify ($) {
  my $self = shift;

  my $t = $self->{t};
  return
      join "\n",
      map { join "\t", $_, $t->{$_} }
      sort { $t->{$b} <=> $t->{$a} }
      keys %$t;
} # stringify

1;
