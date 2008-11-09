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

my @content_type =
(
 {type => 'text/x-suikawiki', label => 'SWML'},
 {type => 'text/x.suikawiki.image'},
 {type => 'application/x.suikawiki.config'},
 {type => 'text/plain', label => 'Plain text'},
 {type => 'text/css', label => 'CSS'},
);

sub AA_NS () { q<http://pc5.2ch.net/test/read.cgi/hp/1096723178/aavocab#> }
sub HTML_NS () { q<http://www.w3.org/1999/xhtml> }
sub SW09_NS () { q<urn:x-suika-fam-cx:markup:suikawiki:0:9:> }
sub SW10_NS () { q<urn:x-suika-fam-cx:markup:suikawiki:0:10:> }
sub XML_NS () { q<http://www.w3.org/XML/1998/namespace> }

require Message::DOM::DOMImplementation;
my $dom = Message::DOM::DOMImplementation->new;

my $path = $cgi->path_info;
$path = '' unless defined $path;

my $param;
if ($path =~ s[;([^/]*)\z][]) {
  $param = percent_decode ($1);
}

my @path = map { s/\+/%2F/g; percent_decode ($_) } split m#/#, $path, -1;
shift @path;

require SWE::DB::SuikaWiki3;

my $sw3_content_db = SWE::DB::SuikaWiki3->new;
$sw3_content_db->{root_directory_name} = q[/home/wakaba/public_html/-temp/wiki/wikidata/page/];

require SWE::DB::SuikaWiki3Props;
my $sw3_prop_db = SWE::DB::SuikaWiki3Props->new;
$sw3_prop_db->{root_directory_name} = $sw3_content_db->{root_directory_name};

require SWE::DB::SuikaWiki3LastModified;
my $sw3_lm_db = SWE::DB::SuikaWiki3LastModified->new;
$sw3_lm_db->{file_name} = $sw3_content_db->{root_directory_name} .
    'mt--6C6173745F6D6F646966696564.dat';

require SWE::DB::SuikaWiki3PageList;
my $sw3_pages = SWE::DB::SuikaWiki3PageList->new;
$sw3_pages->{file_name} = 'data/sw3pages.txt';

require SWE::DB::Lock;
my $names_lock = SWE::DB::Lock->new;
$names_lock->{file_name} = 'data/ids.lock';
    ## NOTE: This lock MUST be used when $sw3pages or $name_prop_db is updated.

require SWE::DB::IDGenerator;
my $idgen = SWE::DB::IDGenerator->new;
$idgen->{file_name} = 'data/nextid.dat';
$idgen->{lock_file_name} = 'data/nextid.lock';

require SWE::DB::IDProps;
my $id_prop_db = SWE::DB::IDProps->new;
$id_prop_db->{root_directory_name} = q[data/ids/];
$id_prop_db->{leaf_suffix} = '.props';

require SWE::DB::IDLocks;
my $id_locks = SWE::DB::IDLocks->new;
$id_locks->{root_directory_name} = $id_prop_db->{root_directory_name};
$id_locks->{leaf_suffix} = '.lock';

require SWE::DB::HashedProps;

my $name_prop_db = SWE::DB::HashedProps->new;
$name_prop_db->{root_directory_name} = q[data/names/];
$name_prop_db->{leaf_suffix} = '.props';

require SWE::DB::IDDOM;

my $content_cache_db = SWE::DB::IDDOM->new;
$content_cache_db->{root_directory_name} = $id_prop_db->{root_directory_name};
$content_cache_db->{leaf_suffix} = '.domcache';

my $cache_prop_db = SWE::DB::IDProps->new;
$cache_prop_db->{root_directory_name} = $content_cache_db->{root_directory_name};
$cache_prop_db->{leaf_suffix} = '.cacheprops';

require SWE::DB::IDText;
my $content_db = SWE::DB::IDText->new;
$content_db->{root_directory_name} = $id_prop_db->{root_directory_name};
$content_db->{leaf_suffix} = '.txt';

if ($path[0] eq 'n' and @path == 2) {
  my $name = $path[1];

  unless (defined $param) {
    my $ids = get_ids_by_name ($name);
    unless (ref $ids) {
      $ids = convert_sw3_page ($ids => $name);
    }

    if (@$ids > 1) {
      ## TODO: ...
    } elsif (@$ids == 0) {
      ## TODO: ...
      exit;
    }
    
    my $id = shift @$ids;
    my $format = $cgi->get_parameter ('format') // 'html';

    if ($format eq 'text') {
      my $content = $content_db->get_data ($id);

      print qq[Content-Type: text/x-suikawiki; charset=utf-8\n\n];
      print $$content;
      exit;
    } elsif ($format eq 'xml') {
      my $doc = get_xml_data ($id);

      print qq[Content-Type: application/xml; charset=utf-8\n\n];

      if (scalar $cgi->get_parameter ('styled')) {
        print q[<?xml-stylesheet href="http://suika.fam.cx/www/style/swml/structure"?>];
      }
 
      print $doc->inner_html;
      exit;
    } else {
      require Whatpm::SWML::Parser;
      my $p = Whatpm::SWML::Parser->new;
      
      my $xml_doc = get_xml_data ($id);

      my $html_doc = $dom->create_document;
      $html_doc->manakai_is_html (1);
      $html_doc->inner_html ('<!DOCTYPE HTML><title></title>');
      
      $html_doc->get_elements_by_tag_name ('title')->[0]->text_content ($name);
      my $head_el = $html_doc->last_child->first_child;
      my $link_el = $html_doc->create_element_ns (HTML_NS, 'link');
      $link_el->set_attribute (rel => 'stylesheet');
      $link_el->set_attribute (href => '/www/style/html/xhtml');
      $head_el->append_child ($link_el);
      
      my $body_el = $html_doc->last_child->last_child;

      my $h1_el = $html_doc->create_element_ns (HTML_NS, 'h1');
      $h1_el->text_content ($name);
      $body_el->append_child ($h1_el);

      my $nav_el = $html_doc->create_element_ns (HTML_NS, 'div');
      $nav_el->set_attribute (class => 'nav');
      $nav_el->inner_html (q[<a rel=edit>Edit</a>]);
      $nav_el->first_child->set_attribute (href => '../i/' . $id . ';edit');
      $body_el->append_child ($nav_el);
      
      my $article_el = convert_swml_to_html ($name, $xml_doc => $html_doc);
      $body_el->append_child ($article_el);

      print qq[Content-Type: text/html; charset=utf-8\n\n];
      print $html_doc->inner_html;
      exit;
    }

    exit;
  } elsif ($param eq 'metadata') {
    binmode STDOUT, ':encoding(utf-8)';
    print qq[Content-Type: text/plain; charset=utf-8\n\n];
    
    print qq[Content ids:\n];
    
    my $ids = get_ids_by_name ($path[1]);
    print qq[\t$_\n] for @{$ids};

    exit;
  }
} elsif ($path[0] eq 'i' and @path == 2) {
  unless (defined $param) {
    if ($cgi->request_method eq 'POST' or
        $cgi->request_method eq 'PUT') {
      my $id = $path[1] + 0;
      
      my $id_lock = $id_locks->get_lock ($id);
      $id_lock->lock;
      
      my $id_prop = $id_prop_db->get_data ($id);
      if ($id_prop) {
        my $ct = $cgi->get_parameter ('content-type') // 'text/x-suikawiki';
        my $valid_ct;
        for (@content_type) {
          if ($_->{type} eq $ct) {
            $valid_ct = 1;
            last;
          }
        }
        unless ($valid_ct) {
          ## TODO: 400
          exit;
        }

        my $prev_hash = $cgi->get_parameter ('hash') // '';
        my $current_hash = $id_prop->{hash} //
            get_hash ($content_db->get_data ($id) // '');
        unless ($prev_hash eq $current_hash) {
          ## TODO: conflict
          exit;
        }

        my $textref = \ ($cgi->get_parameter ('text') // '');

        $id_prop->{'content-type'} = $ct;
        $id_prop->{modified} = time;
        $id_prop->{hash} = get_hash ($textref);

        $content_db->set_data ($id => $textref);
        $id_prop_db->set_data ($id => $id_prop);

        print qq[Status: 204 Saved\n\n];
        
        exit;
      } else {
        ## NOTE: 404
        #
      }
    } else {
      ## TODO: method not allowed
    }
  } elsif ($param eq 'edit') {
    my $id = $path[1] + 0;
    
    my $textref = $content_db->get_data ($id);
    if (defined $textref) {
      binmode STDOUT, ':encoding(utf-8)';
      print qq[Content-Type: text/html; charset=utf-8\n\n];
      
      my $html_doc = $dom->create_document;
      $html_doc->manakai_is_html (1);
      $html_doc->inner_html (q[<!DOCTYPE HTML><title>Edit</title>
<link rel=stylesheet href="/www/style/html/xhtml">
<h1>Edit</h1>
<form method=post accept-charset=utf-8>
<p><button type=submit>Save</button>
<p><textarea name=text></textarea>
<p><button type=submit>Save</button>
<input type=hidden name=hash>
<select name=content-type></select>
</form>]);
      my $form_el = $html_doc->get_elements_by_tag_name ('form')->[0];
      $form_el->set_attribute (action => $id);
      my $ta_el = $form_el->get_elements_by_tag_name ('textarea')->[0];
      $ta_el->text_content ($$textref);

      my $id_prop = $id_prop_db->get_data ($id);

      my $hash = $id_prop->{hash} // get_hash ($textref);
      my $hash_field = $form_el->get_elements_by_tag_name ('input')->[0];
      $hash_field->set_attribute (value => $hash);

      my $ct = $id_prop->{'content-type'} // 'text/x-suikawiki';
      my $has_ct;
      my $select_el = $form_el->get_elements_by_tag_name ('select')->[0];
      for (@content_type) {
        next unless defined $_->{label};
        my $option_el = $html_doc->create_element_ns (HTML_NS, 'option');
        $option_el->set_attribute (value => $_->{type});
        $option_el->text_content ($_->{label});
        if ($_->{type} eq $ct) {
          $option_el->set_attribute (selected => '');
          $has_ct = 1;
        }
        $select_el->append_child ($option_el);
      }
      unless ($has_ct) {
        my $option_el = $html_doc->create_element_ns (HTML_NS, 'option');
        $option_el->set_attribute (value => $ct);
        $option_el->text_content ($ct);
        $option_el->set_attribute (selected => '');
        $select_el->append_child ($option_el);
      }
      
      print $html_doc->inner_html;
      exit;
    }
  }
}

print q[Content-Type: text/plain; charset=us-ascii
Status: 404 Not found

404];

exit;


my $templates = {};

BEGIN {

$templates->{''}->{''} = sub {
  my ($items, $item) = @_;

  if ($item->{node}->node_type == $item->{node}->ELEMENT_NODE) {
    unshift @$items,
        map {{%$item, node => $_, parent => $item->{parent}}}
        @{$item->{node}->child_nodes};
  } else {
    $item->{parent}->manakai_append_text ($item->{node}->node_value);
  }
};

$templates->{(HTML_NS)}->{head} = sub { };

$templates->{(HTML_NS)}->{section} = sub {
  my ($items, $item) = @_;

  my $section_el = $item->{doc}->create_element_ns (HTML_NS, 'div');
  $section_el->set_attribute (class => 'section sw-section');
  $item->{parent}->append_child ($section_el);

  unshift @$items,
      map {{%$item, node => $_, parent => $section_el,
            heading_level => $item->{heading_level} + 1}}
      @{$item->{node}->child_nodes};
};

$templates->{(HTML_NS)}->{h1} = sub {
  my ($items, $item) = @_;

  my $h_el = $item->{doc}->create_element_ns
      (HTML_NS,
       'h' . ($item->{heading_level} > 6 ? '6' : $item->{heading_level}));
  $item->{parent}->append_child ($h_el);

  unshift @$items,
      map {{%$item, node => $_, parent => $h_el}}
      @{$item->{node}->child_nodes};
};

$templates->{(HTML_NS)}->{p} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns
      (HTML_NS, $item->{node}->manakai_local_name);
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};
$templates->{(HTML_NS)}->{$_} = $templates->{(HTML_NS)}->{p}
    for qw/
      ul ol dl li dt dd table tbody tr td blockquote pre
      abbr cite code dfn kbd ruby samp span sub sup time var em strong rt
    /;


$templates->{(SW09_NS)}->{insert} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'ins');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW09_NS)}->{delete} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'del');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW10_NS)}->{'comment-p'} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'p');
  $item->{parent}->append_child ($el);
  $el->set_attribute (class => 'sw-comment-p');

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW10_NS)}->{ed} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'p');
  $item->{parent}->append_child ($el);
  $el->set_attribute (class => 'sw-ed');

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(AA_NS)}->{aa} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'span');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-aa';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW10_NS)}->{csection} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'cite');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-csection';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW10_NS)}->{key} = sub {
  my ($items, $item) = @_;

  my $el0 = $item->{doc}->create_element_ns (HTML_NS, 'kbd');
  $item->{parent}->append_child ($el0);

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'kbd');
  $el0->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW10_NS)}->{qn} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'code');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-qn';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW10_NS)}->{src} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'cite');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-src';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW09_NS)}->{weak} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'small');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-weak';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW10_NS)}->{title} = sub {
  my ($items, $item) = @_;

  unless ($item->{parent}->has_attribute ('title')) {
    $item->{parent}->set_attribute (title => $item->{node}->text_content);
  }
};

$templates->{(SW10_NS)}->{nsuri} = sub {
  my ($items, $item) = @_;

  unless ($item->{parent}->has_attribute ('title')) {
    $item->{parent}->set_attribute
        (title => '<' . $item->{node}->text_content . '>');
  }
};

$templates->{(HTML_NS)}->{q} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns
      (HTML_NS, $item->{node}->manakai_local_name);
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  if ($item->{node}->has_attribute_ns (SW09_NS, 'resScheme')) {
    ## TODO: ...
  }

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};
$templates->{(HTML_NS)}->{del} = $templates->{(HTML_NS)}->{q};
$templates->{(HTML_NS)}->{ins} = $templates->{(HTML_NS)}->{q};

$templates->{(SW09_NS)}->{rubyb} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'ruby');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-rubyb';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW09_NS)}->{anchor} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'a');
  $item->{parent}->append_child ($el);
  $el->set_attribute (class => 'sw-anchor');

  my $url = get_page_url ($item->{node}->text_content, $item->{name});
  $el->set_attribute (href => $url);

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW09_NS)}->{'anchor-internal'} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'a');
  $item->{parent}->append_child ($el);
  $el->set_attribute (class => 'sw-anchor-internal');

  my $id = $item->{node}->get_attribute_ns (SW09_NS, 'anchor') + 0;
  $el->set_attribute (href => '#anchor-' . $id);

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW09_NS)}->{'anchor-end'} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'a');
  $item->{parent}->append_child ($el);
  $el->set_attribute (class => 'sw-anchor-end');

  my $id = $item->{node}->get_attribute_ns (SW09_NS, 'anchor') + 0;
  $el->set_attribute (id => 'anchor-' . $id);

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW09_NS)}->{'anchor-external'} = sub {
  my ($items, $item) = @_;

  $item->{parent}->manakai_append_text ('<');

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'a');
  $item->{parent}->append_child ($el);
  $el->set_attribute (class => 'sw-anchor-external');

  $item->{parent}->manakai_append_text ('>');

  my $scheme = $item->{node}->get_attribute_ns (SW09_NS, 'resScheme');
  if ($scheme eq 'URI' or $scheme eq 'URL') {
    $el->set_attribute
        (href => $item->{node}->get_attribute_ns (SW09_NS, 'resParameter'));
  } else {
    ## TODO: ...
  }

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

}

sub convert_swml_to_html ($$$) {
  my $name = shift;
  my $swml = shift;
  my $doc = shift;

  my $article_el = $doc->create_element_ns (HTML_NS, 'div');
  $article_el->set_attribute (class => 'article');

  my @items = map {{doc => $doc,
                    heading_level => 1, name => $name,
                    node => $_, parent => $article_el}} @{$swml->child_nodes};
  while (@items) {
    my $item = shift @items;
    my $nsuri = $item->{node}->namespace_uri // '';
    my $ln = $item->{node}->manakai_local_name // '';
    my $template = $templates->{$nsuri}->{$ln} || $templates->{''}->{''};
    $template->(\@items, $item);
  }

  return $article_el;
} # convert_swml_to_html

## A source anchor label in SWML -> URL
sub get_page_url ($$) {
  my ($wiki_name, $base_name) = @_;
  $wiki_name =~ s/\s+/ /g;
  $wiki_name =~ s/^ //;
  $wiki_name =~ s/ $//;
  $wiki_name = 'HomePage' unless length $wiki_name;
  $wiki_name = percent_encode ($wiki_name);
  $wiki_name =~ s/%2F/+/g;
  return $wiki_name;
} # get_page_url

sub htescape ($) {
  my $s = shift;
  $s =~ s/&/&amp;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/"/&quot;/g;
  return $s;
} # htescape

sub percent_encode ($) {
  my $s = Encode::encode ('utf8', $_[0]);
  $s =~ s/([^A-Za-z0-9_~-])/sprintf '%%%02X', ord $1/ges;
  return $s;
} # percent_encode

sub percent_decode ($) { # input should be a byte string.
  my $s = shift;
  $s =~ s/%([0-9A-Fa-f]{2})/pack 'C', hex $1/ge;
  return Encode::decode ('utf-8', $s); # non-UTF-8 octet converted to \xHH
} # percent_decode

sub get_absolute_url ($) {
  return $dom->create_uri_reference ($_[0])
      ->get_absolute_reference ($cgi->request_uri)
      ->get_uri_reference 
      ->uri_reference;
} # get_absolute_url

sub get_xml_data ($) {
  my $id = shift;

  my $id_lock = $id_locks->get_lock ($id);
  $id_lock->lock;

  my $cache_prop = $cache_prop_db->get_data ($id);
  my $cached_hash = $cache_prop->{'cached-hash'};

  my $id_prop;
  if ($cached_hash) {
    $id_prop = $id_prop_db->get_data ($id);
    my $content_hash = $id_prop->{hash} || '';
    
    if ($cached_hash ne $content_hash) {
      undef $cached_hash;
    }
  }

  my $doc;
  if ($cached_hash) {
    $doc = $content_cache_db->get_data ($id);
  } else {
    my $textref = $content_db->get_data ($id);
    if ($textref) {
      require Whatpm::SWML::Parser;
      my $p = Whatpm::SWML::Parser->new;
      
      $doc = $dom->create_document;
      $p->parse_char_string ($$textref => $doc);
      
      $content_cache_db->set_data ($id => $doc);

      $id_prop ||= $id_prop_db->get_data ($id) || {};      
      $id_prop->{hash} = get_hash ($textref);
      $id_prop_db->set_data ($id => $id_prop);

      $cache_prop->{'cached-hash'} = $id_prop->{hash};
      $cache_prop_db->set_data ($id => $cache_prop);
    } else {
      ## Content not found.
      $doc = $dom->create_document;
    }
  }

  $id_lock->unlock;

  return $doc;
} # get_xml_data

sub get_hash ($) {
  require Digest::MD5;
  return Digest::MD5::md5_hex (Encode::encode ('utf8', ${$_[0]}));
} # get_hash

sub get_ids_by_name ($) {
  my $name = shift;

  my $name_prop = $name_prop_db->get_data ($name);
  
  if ($name_prop->{ids}) {
    return $name_prop->{ids};
  } else {
    my $sw3id = $sw3_pages->get_data ($name);

    if (defined $sw3id) {
      return $sw3id; # not an arrayref
    } else {
      return [];
    }
  }
} # get_ids_by_name

sub convert_sw3_page ($$) {
  my ($sw3key => $name) = @_;
  
  $names_lock->lock;
  
  $sw3_pages->reset;
  my $page_key = $sw3_pages->get_data ($name);
      ## NOTE: $page_key is undef if the page has been converted
      ## between the first (in get_ids_by_name) and the second (the
      ## line above) $sw3_pages->get_data calls.

  my $ids;
  if (defined $page_key) {
    my $id = $idgen->get_next_id;
    my $id_lock = $id_locks->get_lock ($id);
    $id_lock->lock;
    
    my $content = $sw3_content_db->get_data ($page_key);
    $content_db->set_data ($id => \$content);
    
    my $id_props = $sw3_prop_db->get_data ($page_key);
    my $lm = $sw3_lm_db->get_data ($name);
    $id_props->{modified} = $lm if defined $lm;
    $id_props->{'converted-from-sw3'} = time;
    $id_props->{'sw3-key'} = $page_key;
    $id_prop_db->set_data ($id => $id_props);

    $id_lock->unlock;
    
    my $name_props = $name_prop_db->get_data ($name);
    push @{$name_props->{ids} ||= []}, $id;
    $ids = $name_props->{ids};
    $name_prop_db->set_data ($name => $name_props);
  } else {
    my $name_props = $name_prop_db->get_data ($name);
    $ids = $name_props->{ids};
  }

  $names_lock->unlock;

  return $ids;
} # convert_sw3_page
