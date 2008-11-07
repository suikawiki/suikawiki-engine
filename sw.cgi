#!/usr/bin/perl
use strict;

use lib qw[/home/httpd/html/www/markup/html/whatpm
           /home/wakaba/work/manakai2/lib
           /home/httpd/html/swe/lib/];

use CGI::Carp qw[fatalsToBrowser];
require Message::CGI::Carp;

require Message::CGI::HTTP;
require Encode;
my $cgi = Message::CGI::HTTP->new;
$cgi->{decoder}->{'#default'} = sub {
  return Encode::decode ('utf-8', $_[1]);
};

our $Lang = 'ja'
    if $cgi->get_meta_variable ('HTTP_ACCEPT_LANGUAGE') =~ /\bja\b/; ## TODO: ...

require Message::DOM::DOMImplementation;
my $dom = Message::DOM::DOMImplementation->new;

my $path = $cgi->path_info;
$path = '' unless defined $path;
$path =~ s/%00/%2F/g;

my @path = split m#/#, percent_decode ($path), -1;
shift @path;

require SWE::DB::SuikaWiki3;

my $db = SWE::DB::SuikaWiki3->new;
$db->{root_directory_name} = q[/home/wakaba/public_html/-temp/wiki/wikidata/page/];

if ($path[0] eq 'pages' and @path > 1) {
  my $key = [@path[1..$#path]];
  
  my $page = $db->get_data ($key);

  if (defined $page) {
    my $format = $cgi->get_parameter ('format');

    binmode STDOUT, ':encoding(utf-8)';

    if ($format eq 'text') {
      print qq[Content-Type: text/x-suikawiki; charset=utf-8\n\n];
      print $page;
      exit;
    } elsif ($format eq 'xml') {
      print qq[Content-Type: application/xml; charset=utf-8\n\n];
      
      require Whatpm::SWML::Parser;
      my $p = Whatpm::SWML::Parser->new;
      
      my $doc = $dom->create_document;
      $p->parse_char_string ($page => $doc);

      if (scalar $cgi->get_parameter ('styled')) {
        print q[<?xml-stylesheet href="http://suika.fam.cx/www/style/swml/structure"?>];
      }
 
      print $doc->inner_html;
      exit;
    } else {

    }
  }
}

print q[Content-Type: text/plain; charset=us-ascii
Status: 404 Not found

404];

sub htescape ($) {
  my $s = shift;
  $s =~ s/&/&amp;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/"/&quot;/g;
  return $s;
} # htescape

sub percent_decode ($) {
  return $dom->create_uri_reference ($_[0])
      ->get_iri_reference
      ->uri_reference;
} # percent_decode

sub get_absolute_url ($) {
  return $dom->create_uri_reference ($_[0])
      ->get_absolute_reference ($cgi->request_uri)
      ->get_iri_reference 
      ->uri_reference;
} # get_absolute_url
