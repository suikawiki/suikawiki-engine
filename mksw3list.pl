#!/usr/bin/perl
use strict;

require Encode::EUCJPSW;

my $root_dir_name = q[/home/wakaba/public_html/-temp/wiki/wikidata/page/];

chdir $root_dir_name;

binmode STDOUT, ':encoding(utf8)';

my $has_keyword;
my $index = 0;

open my $file, "find -name '*.txt' |"
    or die "$0: $!";
while (<$file>) {
  my $file_name = $_;
  $file_name =~ s!^\./!!;
  $file_name =~ tr/\x0D\x0A//d;
  $file_name =~ s/\.txt$//;
  my $keyword = $file_name;
  $keyword =~ s!\.ns/!2F2F!g;
  $keyword =~ s/([0-9A-F]{2})/pack 'C', hex $1/ge;
  $keyword = Encode::decode ('euc-jp-sw', $keyword);
  $keyword =~ s/\s+/ /g;
  $keyword =~ s/^ //;
  $keyword =~ s/ $//;
  $keyword = 'SandBox' unless length $keyword;
  if ($has_keyword->{$keyword}) {
    $keyword .= ' #' . ++$index;
  }
  $has_keyword->{$keyword} = 1;
  print "$file_name $keyword\n";
}
