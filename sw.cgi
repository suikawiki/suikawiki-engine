#!/usr/bin/perl
use strict;

use utf8;

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

my $homepage_name = 'HomePage';
my $license_name = 'Wiki//Page//License';
my $style_url = q<http://suika.fam.cx/swe/styles/sw>;
my $cvs_archives_url = q</gate/cvs/suikawiki/sw4data/>;

my @content_type =
(
 {type => 'text/x-suikawiki', label => 'SWML'},
 {type => 'text/x.suikawiki.image'},
 {type => 'application/x.suikawiki.config'},
 {type => 'text/plain', label => 'Plain text'},
 {type => 'text/css', label => 'CSS'},
);

sub HTML_NS () { q<http://www.w3.org/1999/xhtml> }

require Message::DOM::DOMImplementation;
my $dom = Message::DOM::DOMImplementation->new;

## NOTE: This script requires the server set REQUEST_URI and
## SCRIPT_NAME which is the part of the REQUEST_URI that identifies
## the script.

my $rurl = $dom->create_uri_reference ($cgi->request_uri)
    ->get_uri_reference;
my $sname = $dom->create_uri_reference
    (percent_encode_na ($cgi->get_meta_variable ('SCRIPT_NAME')))
    ->get_absolute_reference ($rurl)
    ->get_uri_reference;
my $path = $rurl->get_relative_reference ($sname);
$path->uri_query (undef);
$path->uri_fragment (undef);

my $param;
if ($path =~ s[;([^/]*)\z][]) {
  $param = percent_decode ($1);
}
my $dollar;
if ($path =~ s[\$([^/]*)\z][]) {
  $dollar = percent_decode ($1);
}

my @path = map { s/\+/%2F/g; percent_decode ($_) } split m#/#, $path, -1;
shift @path; # script's name

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

require SWE::DB::SuikaWiki3PageList2;
my $sw3_pages = SWE::DB::SuikaWiki3PageList2->new;
$sw3_pages->{root_directory_name} = 'data/sw3pages/';

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

my $html_cache_db = SWE::DB::IDDOM->new;
$html_cache_db->{root_directory_name} = $id_prop_db->{root_directory_name};
$html_cache_db->{leaf_suffix} = '.htmlcache';

my $cache_prop_db = SWE::DB::IDProps->new;
$cache_prop_db->{root_directory_name} = $content_cache_db->{root_directory_name};
$cache_prop_db->{leaf_suffix} = '.cacheprops';

require SWE::DB::IDText;
my $content_db = SWE::DB::IDText->new;
$content_db->{root_directory_name} = $id_prop_db->{root_directory_name};
$content_db->{leaf_suffix} = '.txt';

if ($path[0] eq 'n' and @path == 2) {
  my $name = normalize_name ($path[1]);
  
  unless (length $name) {
    http_redirect (303, 'See other', get_page_url ($homepage_name, undef));
  }

  unless (defined $param) {
    my $ids = get_ids_by_name ($name);
    unless (ref $ids) {
      $names_lock->lock;
      $sw3_pages->reset;

      $ids = convert_sw3_page ($ids => $name);
      $names_lock->unlock;
    }

    my $id;
    if (defined $dollar) {
      $dollar += 0;
      for (0..$#$ids) {
        if ($ids->[$_] == $dollar) {
          $id = $dollar;
          splice @$ids, $_, 1, ();
          last;
        }
      }
      unless (defined $id) {
        http_redirect (301, 'Not found', get_page_url ($name, undef));
      }
    } else {
      $id = shift @$ids;
    }

    my $format = $cgi->get_parameter ('format') // 'html';

    ## TODO: Is it semantically valid that there is path?format=html
    ## (200) but no path?format=xml (404)?

    if ($format eq 'text' and defined $id) {
      my $content = $content_db->get_data ($id);

      binmode STDOUT, ':encoding(utf-8)';
      print qq[Content-Type: text/x-suikawiki; charset=utf-8\n\n];
      print $$content;
      exit;
    } elsif ($format eq 'xml' and defined $id) {
      my $id_lock = $id_locks->get_lock ($id);
      $id_lock->lock;

      my $id_prop = $id_prop_db->get_data ($id);
      my $cache_prop = $cache_prop_db->get_data ($id);
      my $doc = get_xml_data ($id, $id_prop, $cache_prop);
      
      $id_lock->unlock;

      binmode STDOUT, ':encoding(utf-8)';
      print qq[Content-Type: application/xml; charset=utf-8\n\n];

      if (scalar $cgi->get_parameter ('styled')) {
        print q[<?xml-stylesheet href="http://suika.fam.cx/www/style/swml/structure"?>];
      }
 
      print $doc->inner_html;
      exit;
    } elsif ($format eq 'html') {
      my $html_doc;
      my $article_el;
      if (defined $id) {
        my $id_lock = $id_locks->get_lock ($id);
        $id_lock->lock;
        
        require SWE::Lang::XML2HTML;
        my $html_converter_version = $SWE::Lang::XML2HTML::ConverterVersion;
        
        my $id_prop = $id_prop_db->get_data ($id);
        my $cache_prop = $cache_prop_db->get_data ($id);
        
        my $html_cache_version = $cache_prop->{'html-cache-version'};
        if (defined $html_cache_version and
            $html_cache_version >= $html_converter_version) {
          my $html_cached_hash = $cache_prop->{'html-cached-hash'} // 'x';
          my $current_hash = $id_prop->{hash} // '';
          if ($html_cached_hash eq $current_hash) {
            $html_doc = $html_cache_db->get_data ($id);
          }
        }
        unless ($html_doc) {
          my $xml_doc = get_xml_data ($id, $id_prop, $cache_prop);
          
          $html_doc = $dom->create_document;
          $html_doc->strict_error_checking (0);
          $html_doc->dom_config->set_parameter
              ('http://suika.fam.cx/www/2006/dom-config/strict-document-children' => 0);
          $html_doc->manakai_is_html (1);
          
          $article_el = SWE::Lang::XML2HTML->convert
              ($name, $xml_doc => $html_doc, \&get_page_url);
          $html_doc->text_content ('');
          $html_doc->append_child ($article_el);
          
          $html_cache_db->set_data ($id => $html_doc);
          $cache_prop->{'html-cached-hash'} = $id_prop->{hash};
          $cache_prop->{'html-cache-version'} = $html_converter_version;
          $cache_prop_db->set_data ($id => $cache_prop);
        } else {
          $html_doc->manakai_is_html (1);
          $article_el = $html_doc->document_element;
        }
        
        $id_lock->unlock;
      } else {
        $html_doc = $dom->create_document;
        $html_doc->strict_error_checking (0);
        $html_doc->dom_config->set_parameter
            ('http://suika.fam.cx/www/2006/dom-config/strict-document-children' => 0);
        $html_doc->manakai_is_html (1);
      }

      $html_doc->inner_html ('<!DOCTYPE HTML><title></title>');
      
      $html_doc->get_elements_by_tag_name ('title')->[0]->text_content ($name);
      set_head_content ($html_doc, $id,
                        [{rel => 'alternate',
                          type => 'text/x-suikawiki',
                          href => get_page_url ($name, undef, $id) .
                              '?format=text'},
                         {rel => 'alternate',
                          type => 'application/xml', ## TODO: ok?
                          href => get_page_url ($name, undef, $id) .
                              '?format=xml'}]);
      
      my $body_el = $html_doc->last_child->last_child;

      my $h1_el = $html_doc->create_element_ns (HTML_NS, 'h1');
      my $a_el = $html_doc->create_element_ns (HTML_NS, 'a');
      $a_el->set_attribute (href => get_page_url ($name, undef));
      $a_el->set_attribute (rel => 'bookmark');
      $a_el->text_content ($name);
      $h1_el->append_child ($a_el);
      $body_el->append_child ($h1_el);
      
      if (@$ids) {
        my $ul_el = $html_doc->create_element_ns (HTML_NS, 'ul');
        for my $id (@$ids) {
          my $li_el = $html_doc->create_element_ns (HTML_NS, 'li');
          $li_el->inner_html (q[<a></a>]);
          my $a_el = $li_el->first_child;
          $a_el->text_content ($id);
          $a_el->set_attribute (href => get_page_url ($name, $name, $id));
          $ul_el->append_child ($li_el);
        }
        $body_el->append_child ($ul_el);
      }

      my $nav_el = $html_doc->create_element_ns (HTML_NS, 'div');
      $nav_el->set_attribute (class => 'nav');
      $nav_el->inner_html (q[<a rel=edit>Edit</a> <a href="../new-page">New</a>]);
      if (defined $id) {
        $nav_el->first_child->set_attribute (href => '../i/' . $id . ';edit');
      } else {
        $nav_el->first_child->set_attribute
            (href => '../new-page?names=' . percent_encode ($name));
      }
      $body_el->append_child ($nav_el);

      $body_el->append_child ($article_el) if $article_el;

      my $footer_el = $html_doc->create_element_ns (HTML_NS, 'footer');
      $footer_el->set_attribute (class => 'footer');
      $footer_el->inner_html (q[<p class=copyright><small>&copy; Authors.  See <a rel=license>license terms</a>.  There might also be additional terms applied for this page.</small>]);
      $body_el->append_child ($footer_el);
      
      my $a_el = $footer_el->get_elements_by_tag_name ('a')->[0];
      $a_el->set_attribute (href => get_page_url ($license_name));
      
      binmode STDOUT, ':encoding(utf-8)';
      print qq[Content-Type: text/html; charset=utf-8\n\n];
      print $html_doc->inner_html;
      exit;
    }

    exit;
  } else {
    $name .= '$' . $dollar if defined $dollar;
    $name .= ';' . $param;
    http_redirect (301, 'Not found', get_page_url ($name, undef));
  }
} elsif ($path[0] eq 'i' and @path == 2 and not defined $dollar) {
  unless (defined $param) {
    if ($cgi->request_method eq 'POST' or
        $cgi->request_method eq 'PUT') {
      my $id = $path[1] + 0;
      
      my $id_lock = $id_locks->get_lock ($id);
      $id_lock->lock;
      
      my $id_prop = $id_prop_db->get_data ($id);
      if ($id_prop) {
        my $ct = get_content_type_parameter ();

        my $prev_hash = $cgi->get_parameter ('hash') // '';
        my $current_hash = $id_prop->{hash} //
            get_hash ($content_db->get_data ($id) // '');
        unless ($prev_hash eq $current_hash) {
          ## TODO: conflict
          exit;
        }

        my $textref = \ ($cgi->get_parameter ('text') // '');
        normalize_content ($textref);

        $id_prop->{'content-type'} = $ct;
        $id_prop->{modified} = time;
        $id_prop->{hash} = get_hash ($textref);

        require SWE::DB::VersionControl;
        my $vc = SWE::DB::VersionControl->new;
        local $content_db->{version_control} = $vc;
        local $id_prop_db->{version_control} = $vc;
        
        $content_db->set_data ($id => $textref);
        $id_prop_db->set_data ($id => $id_prop);

        my $user = $cgi->remote_user // '(anon)';
        $vc->commit_changes ("updated by $user");

        my $url = get_page_url ([keys %{$id_prop->{name} or {}}]->[0],
                                undef, 0 + $id);
        http_redirect (301, 'Saved', $url);
        #print qq[Status: 204 Saved\n\n];
        #exit;
      } else {
        http_error (404, 'Not found');
      }
    } else {
      http_error (405, 'Method not allowed', 'PUT');
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
<h1>Edit</h1>
<div class="nav swe-names"></div>

<div class=section>
<h2>Page body</h2>

<form method=post accept-charset=utf-8>
<p><button type=submit>Update</button>
<p><textarea name=text></textarea>
<p><button type=submit>Update</button>
<input type=hidden name=hash>
<select name=content-type></select>
See <a rel=license>License</a> page.
</form>

</div>

<div class=section>
<h2>Page name(s)</h2>

<form method=post accept-charset=utf-8>
<p><textarea name=names></textarea>
<p><button type=submit>Save</button>
</form>
</div>
]);
      set_head_content ($html_doc, $id);
      my $form_el = $html_doc->get_elements_by_tag_name ('form')->[0];
      $form_el->set_attribute (action => $id);
      my $ta_el = $form_el->get_elements_by_tag_name ('textarea')->[0];
      $ta_el->text_content ($$textref);

      my $id_prop = $id_prop_db->get_data ($id);

      my $hash = $id_prop->{hash} // get_hash ($textref);
      my $hash_field = $form_el->get_elements_by_tag_name ('input')->[0];
      $hash_field->set_attribute (value => $hash);

      my $ct = $id_prop->{'content-type'} // 'text/x-suikawiki';
      set_content_type_options
          ($html_doc,
           $form_el->get_elements_by_tag_name ('select')->[0] => $ct);

      my $a_el = $form_el->get_elements_by_tag_name ('a')->[0];
      $a_el->set_attribute (href => get_page_url ($license_name));

      $form_el = $html_doc->get_elements_by_tag_name ('form')->[1];
      $form_el->set_attribute (action => $id . ';names');
      
      my $names = $id_prop->{name} || {};
      $ta_el = $form_el->get_elements_by_tag_name ('textarea')->[0];
      $ta_el->text_content (join "\x0A", keys %$names);

      my $nav_el = $html_doc->get_elements_by_tag_name ('div')->[0];
      for (keys %$names) {
        my $a_el = $html_doc->create_element_ns (HTML_NS, 'a');
        $a_el->set_attribute (href => get_page_url ($_, undef, $id));
        $a_el->text_content ($_);
        $nav_el->append_child ($a_el);
        $nav_el->manakai_append_text (' ');
      }
     
      print $html_doc->inner_html;
      exit;
    }
  } elsif ($param eq 'names') {
    if ($cgi->request_method eq 'POST' or
        $cgi->request_method eq 'PUT') {
      my $id = $path[1] + 0;

      require SWE::DB::VersionControl;
      my $vc = SWE::DB::VersionControl->new;
      local $name_prop_db->{version_control} = $vc;
      local $id_prop_db->{version_control} = $vc;
      
      $names_lock->lock;
      
      my $id_prop = $id_prop_db->get_data ($id);
      my $old_names = $id_prop->{name} || {};
      
      my $new_names = {};
      for (split /\x0D\x0A?|\x0A/, $cgi->get_parameter ('names')) {
        $new_names->{normalize_name ($_)} = 1;
      }
      $new_names->{'(no title)'} = 1 unless keys %$new_names;

      my $added_names = {};
      my $removed_names = {%$old_names};
      for (keys %$new_names) {
        if ($old_names->{$_}) {
          delete $removed_names->{$_};
        } else {
          $added_names->{$_} = 1;
        }
      }
      
      for my $new_name (keys %$added_names) {
        my $new_name_prop = $name_prop_db->get_data ($new_name);
        unless (defined $new_name_prop) {
          my $sw3id = $sw3_pages->get_data ($new_name);
          convert_sw3_page ($sw3id => $new_name);                    
          $new_name_prop = $name_prop_db->get_data ($new_name);
        }
        $new_name_prop->{name} = $new_name;
        push @{$new_name_prop->{id} ||= []}, $id;
        $name_prop_db->set_data ($new_name => $new_name_prop);
      }

      for my $removed_name (keys %$removed_names) {
        my $removed_name_prop = $name_prop_db->get_data ($removed_name);
        for (0..$#{$removed_name_prop->{id} or []}) {
          if ($removed_name_prop->{id}->[$_] eq $id) {
            splice @{$removed_name_prop->{id}}, $_, 1, ();
            last;
          }
        }
        $name_prop_db->set_data ($removed_name => $removed_name_prop);
      }

      $id_prop->{name} = $new_names;
      $id_prop_db->set_data ($id => $id_prop);

      my $user = $cgi->remote_user // '(anon)';
      $vc->commit_changes ("id-name association changed by $user");

      $names_lock->unlock;

      print "Status: 204 Changed\n\n";

      exit;
    } else {
      http_error (405, 'Method not allowed', 'PUT');
    }
  }
} elsif ($path[0] eq 'new-page' and @path == 1) {
  if ($cgi->request_method eq 'POST') {
    require SWE::DB::VersionControl;

    my $new_names = {};
    for (split /\x0D\x0A?|\x0A/, $cgi->get_parameter ('names')) {
      $new_names->{normalize_name ($_)} = 1;
    }
    $new_names->{'(no title)'} = 1 unless keys %$new_names;

    my $user = $cgi->remote_user // '(anon)';
    my $ct = get_content_type_parameter ();

    my $content = $cgi->get_parameter ('text') // '';
    normalize_content (\$content);

    $names_lock->lock;
    my $id = $idgen->get_next_id;

    {
      my $id_lock = $id_locks->get_lock ($id);
      $id_lock->lock;
      
      my $vc = SWE::DB::VersionControl->new;
      local $content_db->{version_control} = $vc;
      local $id_prop_db->{version_control} = $vc;
      $vc->add_file ($idgen->{file_name});
      
      $content_db->set_data ($id => \$content);
      
      my $id_props = {};
      $id_props->{name}->{$_} = 1 for keys %$new_names;
      $id_props->{'content-type'} = $ct;
      $id_props->{modified} = time;
      $id_props->{hash} = get_hash (\$content);
      $id_prop_db->set_data ($id => $id_props);

      $vc->commit_changes ("created by $user");

      $id_lock->unlock;
    }

    my $vc = SWE::DB::VersionControl->new;
    local $name_prop_db->{version_control} = $vc;

    for my $name (keys %$new_names) {
      my $name_props = $name_prop_db->get_data ($name);
      unless (defined $name_props) {
        my $sw3id = $sw3_pages->get_data ($name);
        convert_sw3_page ($sw3id => $name);                    
        $name_props = $name_prop_db->get_data ($name);
      }

      push @{$name_props->{id} ||= []}, $id;
      $name_props->{name} = $name;
      $name_prop_db->set_data ($name => $name_props);
    }

    $vc->commit_changes ("id=$id created by $user");
    
    my $url = get_page_url ([keys %$new_names]->[0], undef, 0 + $id);
    http_redirect (301, 'Created', $url);
  } else {
    binmode STDOUT, ':encoding(utf8)';
    print "Content-Type: text/html; charset=utf-8\n\n";

    my $doc = $dom->create_document;
    $doc->manakai_is_html (1);
    $doc->inner_html (q[<!DOCTYPE HTML><title>New page</title>
<h1>New page</h1>
<form action="" method=post accept-charset=utf-8>
<p><button type=submit>Save</button>
<p><label><strong>Page name(s)</strong>:<br>
<textarea name=names></textarea></label>
<p><label><strong>Page body</strong>:<br>
<textarea name=text></textarea></label>
<p><button type=submit>Save</button>
<select name=content-type></select>
See <a rel=license>License</a> page.
</form>
]);
    set_head_content ($doc);

    my $form_el = $doc->get_elements_by_tag_name ('form')->[0];
    set_content_type_options
        ($doc, $form_el->get_elements_by_tag_name ('select')->[0]);

    my $names = $cgi->get_parameter ('names') // '';
    $form_el->get_elements_by_tag_name ('textarea')->[0]
        ->text_content ($names);

    my $a_el = $form_el->get_elements_by_tag_name ('a')->[0];
    $a_el->set_attribute (href => get_page_url ($license_name));
    
    print $doc->inner_html;
    exit;
  }
} elsif (@path == 1 and
         {'' => 1, 'n' => 1, 'i' => 1}->{$path[0]}) {
  http_redirect (303, 'See other', get_page_url ($homepage_name, undef));
} elsif (@path == 0) {
  my $rurl = $cgi->request_uri;
  $rurl =~ s!\.[^/]*$!!g;
  http_redirect (303, 'See other', $rurl . '/');
}

http_error (404, 'Not found');

sub get_content_type_parameter () {
  my $ct = $cgi->get_parameter ('content-type') // 'text/x-suikawiki';
  
  my $valid_ct;
  for (@content_type) {
    if ($_->{type} eq $ct) {
      $valid_ct = 1;
      last;
    }
  }
  unless ($valid_ct) {
    http_error (400, 'content-type parameter not allowed');
    ## TODO: 406?
  }

  return $ct;
} # get_content_type_parameter

sub set_content_type_options ($$;$) {
  my ($doc, $select_el, $ct) = @_;
  $ct //= 'text/x-suikawiki';
  
  my $has_ct;
  for (@content_type) {
    next unless defined $_->{label};
    my $option_el = $doc->create_element_ns (HTML_NS, 'option');
    $option_el->set_attribute (value => $_->{type});
    $option_el->text_content ($_->{label});
    if ($_->{type} eq $ct) {
      $option_el->set_attribute (selected => '');
      $has_ct = 1;
    }
    $select_el->append_child ($option_el);
  }
  unless ($has_ct) {
    my $option_el = $doc->create_element_ns (HTML_NS, 'option');
    $option_el->set_attribute (value => $ct);
    $option_el->text_content ($ct);
    $option_el->set_attribute (selected => '');
    $select_el->append_child ($option_el);
  }
} # set_content_type_options

sub http_error ($$;$) {
  my ($code, $text, $allowed) = @_;
  binmode STDOUT, ":encoding(utf-8)";
  print qq[Status: $code $text\n];
  print qq[Allow: $allowed\n] if defined $allowed;
  print qq[Content-Type: text/html; charset=utf-8\n\n];
  print qq[<!DOCTYPE HTML>
<html lang=en><title>$code @{[htescape ($text)]}</title>
<link rel=stylesheet href="@{[htescape ($style_url)]}">
<h1>@{[htescape ($text)]}</h1>];
  exit;
} # http_error

sub http_redirect ($$$) {
  my ($code, $text, $url) = @_;
  
  my $abs_url = get_absolute_url ($url);

  binmode STDOUT, ':encoding(utf-8)';
  print qq[Status: $code $text
Location: $abs_url
Content-Type: text/html; charset=utf-8

<!DOCTYPE HTML>
<html lang=en>
<title>$code @{[htescape ($text)]}</title>
<h1>@{[htescape ($text)]}</h1>
<p>See <a href="@{[htescape ($url)]}">other page</a>.];
  exit;
} # http_redirect

sub normalize_name ($) {
  my $s = shift;
  $s =~ tr{\x{3000}\x{FF01}-\x{FF5E}\x{FF61}-\x{FF9F}\x{FFE0}-\x{FFE6}}
          { !-~。「」、・ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン\x{3099}\x{309A}\xA2\xA3\xAC\xAF\xA6\xA5\x{20A9}};
  $s =~ s/\s+/ /g;
  $s =~ s/^ //;
  $s =~ s/ $//;
  return $s;
} # normalize_name

sub normalize_content ($) {
  my $sref = shift;
  $$sref =~ tr{\x{3000}\x{FF01}-\x{FF5E}\x{FF61}-\x{FF9F}\x{FFE0}-\x{FFE6}}
          { !-~。「」、・ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン\x{3099}\x{309A}\xA2\xA3\xAC\xAF\xA6\xA5\x{20A9}};
} # normalize_content

## A source anchor label in SWML -> URL
sub get_page_url ($$;$) {
  my ($wiki_name, $base_name, $id) = @_;
  $wiki_name = percent_encode ($wiki_name);
  $wiki_name =~ s/%2F/+/g;
  if (defined $id) {
    $wiki_name .= '$' . (0 + $id);
  }
  $wiki_name = ('../' x (@path - 1)) . 'n/' . $wiki_name;
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

sub percent_encode_na ($) {
  my $s = Encode::encode ('utf8', $_[0]);
  $s =~ s/([^\x00-\x7F])/sprintf '%%%02X', ord $1/ges;
  return $s;
} # percent_encode_na

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

sub get_xml_data ($$$) {
  my ($id, $id_prop, $cache_prop) = @_;

  my $cached_hash = $cache_prop->{'cached-hash'};

  if ($cached_hash) {
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

      $cache_prop->{'cached-hash'} = get_hash ($textref);
      $cache_prop_db->set_data ($id => $cache_prop);
    } else {
      ## Content not found.
      $doc = $dom->create_document;
    }
  }

  return $doc;
} # get_xml_data

sub get_hash ($) {
  require Digest::MD5;
  return Digest::MD5::md5_hex (Encode::encode ('utf8', ${$_[0]}));
} # get_hash

sub get_ids_by_name ($) {
  my $name = shift;

  my $name_prop = $name_prop_db->get_data ($name);
  
  if ($name_prop->{id}) {
    return $name_prop->{id};
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
  
  my $page_key = $sw3_pages->get_data ($name);
      ## NOTE: $page_key is undef if the page has been converted
      ## between the first (in get_ids_by_name) and the second (the
      ## line above) $sw3_pages->get_data calls.

  my $ids;
  if (defined $page_key) {
    my $id = $idgen->get_next_id;
    my $id_lock = $id_locks->get_lock ($id);
    $id_lock->lock;

    require SWE::DB::VersionControl;
    my $vc = SWE::DB::VersionControl->new;
    local $content_db->{version_control} = $vc;
    local $id_prop_db->{version_control} = $vc;
    $vc->add_file ($idgen->{file_name});
    
    my $content = $sw3_content_db->get_data ($page_key);
    $content_db->set_data ($id => \$content);
    
    my $id_props = $sw3_prop_db->get_data ($page_key);
    my $lm = $sw3_lm_db->get_data ($name);
    $id_props->{name}->{$name} = 1;
    $id_props->{modified} = $lm if defined $lm;
    $id_props->{'converted-from-sw3'} = time;
    $id_props->{'sw3-key'} = $page_key;
    $id_props->{hash} = get_hash (\$content);
    $id_prop_db->set_data ($id => $id_props);

    $vc->commit_changes ("converted from SuikaWiki3 <http://suika.fam.cx/gate/cvs/suikawiki/wikidata/page/$page_key.txt>");

    $id_lock->unlock;

    $vc = SWE::DB::VersionControl->new;
    local $name_prop_db->{version_control} = $vc;
    local $sw3_pages->{version_control} = $vc;
    
    my $name_props = $name_prop_db->get_data ($name);
    push @{$name_props->{id} ||= []}, $id;
    $ids = $name_props->{id};
    $name_props->{name} = $name;
    $name_prop_db->set_data ($name => $name_props);

    $sw3_pages->delete_data ($name);
    $sw3_pages->save_data;
    
    $vc->commit_changes ("converted from SuikaWiki3 <http://suika.fam.cx/gate/cvs/suikawiki/wikidata/page/$page_key.txt>");
  } else {
    my $name_props = $name_prop_db->get_data ($name);
    $ids = $name_props->{id};
  }

  return $ids;
} # convert_sw3_page

sub set_head_content ($;$$) {
  my ($doc, $id, $links) = @_;
  my $head_el = $doc->manakai_head;

  push @{$links ||= []}, {rel => 'stylesheet', href => $style_url},
      {rel => 'license', href => get_page_url ($license_name, undef)};
  
  if (defined $id) {
    push @$links, {rel => 'archives',
                   href => $cvs_archives_url . 'ids/' .
                             int ($id / 1000) . '/' . ($id % 1000) . '.txt'};
  }
  
  for my $item (@$links) {
    my $link_el = $doc->create_element_ns (HTML_NS, 'link');
    for (keys %$item) {
      $link_el->set_attribute ($_ => $item->{$_});
    }
    $head_el->append_child ($link_el);
  }
} # set_head_content
