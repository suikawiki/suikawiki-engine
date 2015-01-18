package SWE::String;
use strict;
use warnings;
use Exporter::Lite;
use Encode;
use Digest::MD5;
use Char::Normalize::FullwidthHalfwidth qw(get_fwhw_normalized);

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

  require Text::MeCab;
  my $mecab = Text::MeCab->new;

  my $all_terms = 0;
  my $terms = {};
  eval {
    for (my $node = $mecab->parse ($_[1]); $node; $node = $node->next) {
      ## XXX support stop words
      ## XXX provide a way to save original representation

      my $term = $node->surface;
      next unless defined $term;
      $term = lc get_fwhw_normalized decode 'utf-8', $term;

      $terms->{$term}++;
    } # $term
  };
  warn $@ if $@;
  
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
