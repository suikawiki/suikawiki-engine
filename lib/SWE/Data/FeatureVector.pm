package SWE::Data::FeatureVector;
use strict;
use warnings;

sub new ($) {
  my $self = bless {t => {}}, shift;
  return $self;
} # new

sub parse_string ($$) {
  my $self = shift->new;
  
  ## TODO: ...
  
  return $self;
} # parse_string

sub set_tfidf ($$$) {
  #my ($self, $term, $tfidf) = @_;
  $_[0]->{t}->{$_[1]} = $_[2];
} # set_tfidf

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
