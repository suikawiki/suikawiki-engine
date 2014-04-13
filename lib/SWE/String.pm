package SWE::String;
use strict;
use warnings;
use Exporter::Lite;
use Encode;
use Digest::MD5;
use Char::Normalize::FullwidthHalfwidth;

our @EXPORT;

push @EXPORT, qw(normalize_name);
sub normalize_name ($) {
  my $s = shift;
  Char::Normalize::FullwidthHalfwidth::normalize_width (\$s);
  $s =~ s/\s+/ /g;
  $s =~ s/^ //;
  $s =~ s/ $//;
  return $s;
} # normalize_name

push @EXPORT, qw(normalize_content);
sub normalize_content ($) {
  my $sref = shift;
  Char::Normalize::FullwidthHalfwidth::normalize_width ($sref);
} # normalize_content

push @EXPORT, qw(string_hash);
sub string_hash ($) {
  return Digest::MD5::md5_hex (encode ('utf8', $_[0]));
} # string_hash

push @EXPORT, qw(for_unique_words);
sub for_unique_words (&$) {
  #my ($code, $string) = @_;
  
  ## TODO: use mecab

  require Text::Kakasi;
  my $k = Text::Kakasi->new;
  
  ## TODO: support stop words
  
  my $all_terms = 0;
  my $terms = {};
  for my $term (split /\s+/, $k->set (qw/-iutf8 -outf8 -w/)->get ($_[1])) {

    ## TODO: provide a way to save original representation

    ## TODO: more normalization
    $term = lc $term;

    $terms->{$term}++;
  }
  
  for my $term (keys %$terms) {
    $_[0]->($term, $terms->{$term});
  }
} # for_unique_words

1;

=head1 LICENSE

Copyright 2002-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
