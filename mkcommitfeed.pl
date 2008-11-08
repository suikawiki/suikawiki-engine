#!/usr/bin/perl
use strict;

use Getopt::Long;
use Pod::Usage;
use Time::Local;

my $file_name;
my $feed_url;
my $feed_title = 'ChangeLog';
my $feed_author_name;
my $feed_author_mail;
my $feed_author_url;
my $feed_lang = 'i-default';
my $feed_related_url;
my $feed_license_url;
my $feed_rights;
my $entry_content;
my $entry_author_name;
my $entry_author_mail;
my $entry_date;
my $entry_title;

GetOptions (
  'entry-author-mail=s' => \$entry_author_mail,
  'entry-author-name=s' => \$entry_author_name,
  'entry-content=s' => \$entry_content,
  'entry-title=s' => \$entry_title,
  'feed-author-mail=s' => \$feed_author_mail,
  'feed-author-name=s' => \$feed_author_name,
  'feed-author-url=s' => \$feed_author_url,
  'feed-lang=s' => \$feed_lang,
  'feed-license-url=s' => \$feed_license_url,
  'feed-related-url=s' => \$feed_related_url,
  'feed-rights=s' => \$feed_rights,
  'feed-title=s' => \$feed_title,
  'feed-url=s' => \$feed_url,
  'file-name=s' => \$file_name,
  'help' => sub {
    pod2usage (-exitval => 0, -verbose => 2);
  },
) or pod2usage (-exitval => 1, -verbose => 1);
pod2usage (-exitval => 1, -verbose => 1,
           -msg => "Required argument --file-name is not specified.\n")
      unless defined $file_name;
pod2usage (-exitval => 1, -verbose => 1,
           -msg => "Required argument --feed-url is not specified.\n")
      unless defined $feed_url;

unless (defined $entry_content) {
  $entry_content = '';
  $entry_content .= $_ while <>;
}

if ($entry_content =~ /^(\d+)-(\d+)-(\d+)\s+(.+)<([^<>]+)>/m) {
#  $entry_date //= timegm (0, 0, 0, $3, $2-1, $1);
  $entry_author_name //= $4;
  $entry_author_mail //= $5;
  $entry_author_name =~ s/\s+$//;
}
$entry_date //= time;

pod2usage (-exitval => 1, -verbose => 1,
           -msg => "Required argument --entry-author-name is not specified.\n")
      unless defined $entry_author_name;

unless (defined $entry_title) {
  my $time = [gmtime $entry_date];
  $entry_title = sprintf '%04d-%02d-%02d %s', 1900+$time->[5], 1+$time->[4],
      $time->[3], $entry_author_name;
}

require Message::DOM::DOMImplementation;
my $dom = Message::DOM::DOMImplementation->new;
my $doc;

{
  if (-f $file_name) {
    open my $file, '<:encoding(utf8)', $file_name or die "$0: $file_name: $!";
    local $/ = undef;
    $doc = $dom->create_document;
    $doc->inner_html (<$file>);
  } else {
    $doc = $dom->create_atom_feed_document
        ($feed_url, $feed_title, $feed_lang);
  }
}

$doc->dom_config
    ->{q<http://suika.fam.cx/www/2006/dom-config/create-child-element>} = 1;
my $feed = $doc->document_element;
unless ($feed) {
  $feed = $doc->create_element_ns ('http://www.w3.org/2005/Atom', 'feed');
  $doc->append_child ($feed);
}
$feed->set_attribute_ns ('http://www.w3.org/2000/xmlns/',
                         'xmlns', $feed->namespace_uri);

unless (@{$feed->author_elements}) {
  if (defined $feed_author_name) {
    my $author = $doc->create_element_ns ($feed->namespace_uri, 'author');
    $author->name ($feed_author_name);
    $author->email ($feed_author_mail) if defined $feed_author_mail;
    $author->uri ($feed_author_url) if defined $feed_author_url;
    $feed->append_child ($author);
  }
}
unless (@{$feed->link_elements}) {
  my $link_self = $doc->create_element_ns ($feed->namespace_uri, 'link');
  $link_self->rel ('self');
  $link_self->type ('application/atom+xml');
  $link_self->hreflang ($feed_lang);
  $link_self->href ($feed_url);
  $feed->append_child ($link_self);

  if (defined $feed_related_url) {
    my $link = $doc->create_element_ns ($feed->namespace_uri, 'link');
    $link->rel ('related');
    $link->href ($feed_related_url);
    $feed->append_child ($link);
  }

  if (defined $feed_license_url) {
    my $link = $doc->create_element_ns ($feed->namespace_uri, 'link');
    $link->rel ('license');
    $link->href ($feed_license_url);
    $feed->append_child ($link);
  }
}

if (defined $feed_rights) {
  $feed->rights_element->text_content ($feed_rights);
}

my $entry_id = 'entry-' . time;
my $entry = $feed->add_new_entry ($feed_url . '#' . $entry_id,
                                  $entry_title);
$entry->set_attribute_ns ('http://www.w3.org/XML/1998/namespace',
                          'xml:id' => $entry_id);
if (defined $entry_author_name) {
  my $author = $doc->create_element_ns ($feed->namespace_uri, 'author');
  $author->name ($entry_author_name);
  $author->email ($entry_author_mail) if defined $entry_author_mail;
  $entry->append_child ($author);
}
$entry->updated_element->value ($entry_date);
my $content = $entry->content_element;
$content->type ('text');
$content->text_content ($entry_content);

{
  open my $file, '>:utf8', $file_name or die "$0: $file_name: $!";
  print $file $doc->inner_html;
}

## $Date: 2008/11/08 09:30:51 $
