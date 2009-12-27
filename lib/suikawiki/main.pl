use strict;
use feature 'state';

## --- Configurations

our $db_dir_name;
my $db_sw3_dir_name = $db_dir_name . 'sw3pages/';
my $db_global_lock_dir_name = $db_dir_name;
my $db_id_dir_name = $db_dir_name . q[ids/];
my $db_name_dir_name = $db_dir_name . q[names/];

## --- Common modules

require Encode;

require Message::DOM::DOMImplementation;
my $dom = Message::DOM::DOMImplementation->new;

use Message::CGI::Util qw/percent_encode percent_encode_na
  percent_decode htescape get_absolute_url
  datetime_in_content/;

require Char::Normalize::FullwidthHalfwidth;

use SWE::Lang qw/@ContentMediaType/;

## --- Prepares database access variables (commonly used ones)

require SWE::DB;
my $db = SWE::DB->new;
$db->db_dir_name = $db_dir_name;
$db->global_lock_dir_name = $db_global_lock_dir_name;
$db->id_dir_name = $db_id_dir_name;
$db->name_dir_name = $db_name_dir_name;
$db->sw3db_dir_name = $db_sw3_dir_name;

require SWE::DB::SuikaWiki3PageList2;
my $sw3_pages = SWE::DB::SuikaWiki3PageList2->new;
$sw3_pages->{root_directory_name} = $db_sw3_dir_name;

require SWE::DB::Lock;
my $names_lock = SWE::DB::Lock->new;
$names_lock->{file_name} = $db_global_lock_dir_name . 'ids.lock';
$names_lock->lock_type ('Names');
    ## NOTE: This lock MUST be used when $sw3pages or $name_prop_db is updated.

# XXX $db->id_prop
require SWE::DB::IDProps;
my $id_prop_db = SWE::DB::IDProps->new;
$id_prop_db->{root_directory_name} = $db_id_dir_name;
$id_prop_db->{leaf_suffix} = '.props';

require SWE::DB::IDLocks;
my $id_locks = SWE::DB::IDLocks->new;
$id_locks->{root_directory_name} = $db_id_dir_name;
$id_locks->{leaf_suffix} = '.lock';

require SWE::DB::HashedProps;
my $name_prop_db = SWE::DB::HashedProps->new;
$name_prop_db->{root_directory_name} = $db_name_dir_name;
$name_prop_db->{leaf_suffix} = '.props';

my $cache_prop_db = SWE::DB::IDProps->new;
$cache_prop_db->{root_directory_name} = $db_id_dir_name;
$cache_prop_db->{leaf_suffix} = '.cacheprops';

require SWE::DB::IDText;
my $content_db = SWE::DB::IDText->new;
$content_db->{root_directory_name} = $db_id_dir_name;
$content_db->{leaf_suffix} = '.txt';

## --- Process Request-URI

require Message::CGI::HTTP;
my $cgi = Message::CGI::HTTP->new;
$cgi->{decoder}->{'#default'} = sub {
  return Encode::decode ('utf-8', $_[1]);
};

## NOTE: This script requires the server set REQUEST_URI and
## SCRIPT_NAME which is the part of the REQUEST_URI that identifies
## the script.

my $ru;
if ($ENV{QUERY_STRING} =~ s/(?:^|&)ru=([^&]+)//) {
  $ru = $1;
}
if (defined $ru and length $ru) {
  $ENV{REQUEST_URI} = $ru;
  #warn "RU: $ru";
}

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

## --- Process request and generate response

sub HTML_NS () { q<http://www.w3.org/1999/xhtml> }

if ($path[0] eq 'n' and @path == 2) {
  my $name = normalize_name ($path[1]);
  
  unless (length $name) {
    our $homepage_name;
    http_redirect (303, 'See other', get_page_url ($homepage_name, undef));
    exit;
  }

  unless (defined $param) {
    my ($id, $ids) = prepare_by_name ($name, $dollar);

    if (defined $dollar and not defined $id) {
      http_redirect (301, 'Not found', get_page_url ($name, undef));
      exit;
    }

    my $format = $cgi->get_parameter ('format') // 'html';

    ## TODO: Is it semantically valid that there is path?format=html
    ## (200) but no path?format=xml (404)?
    
    require SWE::Object::Document;
    my $docobj = SWE::Object::Document->new (id => $id, db => $db);
    $docobj->rebless;

    if ($format eq 'text' and defined $id) {
      $docobj->{content_db} = $content_db; ## XXX
      $docobj->{id_prop_db} = $id_prop_db; ## XXX

      binmode STDOUT, ':encoding(utf-8)';
      print qq[X-SW-Hash: @{[ $id_prop_db->get_data ($id)->{hash} ]}\n];
      print qq[Content-Type: @{[$docobj->to_text_media_type]}; charset=utf-8\n\n];
      print ${$docobj->to_text};
      exit;
    } elsif ($format eq 'xml' and defined $id) {
      ## XXX
      $docobj->{content_db} = $content_db; ## XXX
      $docobj->{id_prop_db} = $id_prop_db;
      $docobj->{cache_prop_db} = $cache_prop_db;
      $docobj->{swml_to_xml} = \&get_xml_data;

      my $xmldoc = $docobj->to_xml (styled => scalar $cgi->get_parameter ('styled'));
      if ($xmldoc) {
        binmode STDOUT, ':encoding(utf-8)';
        print qq[Content-Type: @{[$docobj->to_xml_media_type]}; charset=utf-8\n\n];
        
        print $xmldoc->inner_html;
      } else {
        http_error (406, q{format=xml is not supported for this page});
      }
      exit;
    } elsif ($format eq 'html') {
      my $html_doc;
      my $html_container;
      my $title_text;
      my $id_prop;
      
      if (defined $id) {
        # XXX
        $docobj->{id_prop_db} = $id_prop_db;
        $docobj->{cache_prop_db} = $cache_prop_db;
        $docobj->{content_db} = $content_db; ## XXX
        $docobj->{swml_to_xml} = \&get_xml_data;
        $docobj->{name} = $name;
        $docobj->{get_page_url} = \&get_page_url;

        $docobj->lock;
        ($html_doc, $html_container) = $docobj->to_html_fragment;

        $id_prop = $id_prop_db->get_data ($id);
        $title_text = $id_prop->{title};
        ## TODO: $title_type
        
        $docobj->unlock;
      }

      unless ($html_doc) {
        $html_doc = $dom->create_document;
        $html_doc->strict_error_checking (0);
        $html_doc->dom_config->set_parameter
            ('http://suika.fam.cx/www/2006/dom-config/strict-document-children' => 0);
        $html_doc->manakai_is_html (1);
      }

      $html_doc->inner_html ('<!DOCTYPE HTML><title></title>');
      
      $html_doc->get_elements_by_tag_name ('title')->[0]->text_content ($name);
      
      my @link;
      
      my $tmt = $docobj->to_text_media_type;
      if (defined $tmt) {
        push @link, {rel => 'alternate', type => $tmt,
                     href => get_page_url ($name, undef, $id) . '?format=text'};
      }

      my $xmt = $docobj->to_xml_media_type;
      if (defined $xmt) {
        push @link, {rel => 'alternate', type => $xmt,
                     href => get_page_url ($name, undef, $id) . '?format=xml'};
      }
      
      push @link, {rel => 'archives',
                   href => get_page_url ($name, undef, undef) . ';history',
                   title => 'History of the page name'};
      if (defined $id) {
        push @link, {rel => 'archives',
                     href => '../i/' . $id . ';history',
                     title => 'History of the page content'};
      }
      set_head_content ($html_doc, $id, \@link);
      
      my $body_el = $html_doc->last_child->last_child;

      my $h1_el = $html_doc->create_element_ns (HTML_NS, 'h1');
      my $a_el = $html_doc->create_element_ns (HTML_NS, 'a');
      $a_el->set_attribute (href => get_page_url ($name, undef));
      $a_el->set_attribute (rel => 'bookmark');
      $a_el->text_content ($name);
      $h1_el->append_child ($a_el);
      $body_el->append_child ($h1_el);
      
      if (@$ids) {
        my $nav_el = $html_doc->create_element_ns (HTML_NS, 'div');
        $nav_el->set_attribute (class => 'nav swe-ids');
        $nav_el->manakai_append_text
            (@$ids == 1 ? 'There is another page with same name:'
                 : 'There are other pages with same name:');
        my $ul_el = $html_doc->create_element_ns (HTML_NS, 'ul');
        for my $id (@$ids) {
          my $li_el = $html_doc->create_element_ns (HTML_NS, 'li');
          $li_el->inner_html (q[<a></a>]);
          my $a_el = $li_el->first_child;
          my $id_prop = $id_prop_db->get_data ($id);
          $a_el->text_content
              (length $id_prop->{title} ? $id_prop->{title}
                 : [keys %{$id_prop->{name}}]->[0] // $id); ## TODO: title-type
          $a_el->set_attribute (href => get_page_url ($name, $name, $id));
          $ul_el->append_child ($li_el);
        }
        $nav_el->append_child ($ul_el);
        $body_el->append_child ($nav_el);
      }

      my $nav_el = $html_doc->create_element_ns (HTML_NS, 'div');
      $nav_el->set_attribute (class => 'nav tools');
      $nav_el->inner_html (q[<a rel=edit>Edit</a> <a href="../new-page">New</a>]);
      if (defined $id) {
        $nav_el->first_child->set_attribute (href => '../i/' . $id . ';edit');
        $body_el->set_attribute ('data-doc-id' => $id);
      } else {
        $nav_el->first_child->set_attribute
            (href => '../new-page?names=' . percent_encode ($name));
      }
      $body_el->append_child ($nav_el);

      if ($html_container) {
        my $article_el = $html_doc->create_element_ns (HTML_NS, 'div');
        $article_el->set_attribute (class => 'article');

        my $h2_el = $html_doc->create_element_ns (HTML_NS, 'h2');
        $h2_el->text_content (length $title_text ? $title_text : $name);
            ## TODO: {'title-type'};
        $article_el->append_child ($h2_el);
        
        while (@{$html_container->child_nodes}) {
          $article_el->append_child ($html_container->first_child);
        }

        my $modified = $id_prop->{modified};
        if (defined $modified) {
          my $footer_el = $html_doc->create_element_ns (HTML_NS, 'div');
          $footer_el->set_attribute (class => 'footer swe-updated');
          $footer_el->inner_html ('Updated: <time></time>');
          $footer_el->last_child->text_content
              (datetime_in_content ($modified));
          $article_el->append_child ($footer_el);
        }
          
        $body_el->append_child ($article_el);
      }

      my $ad_el = $html_doc->create_element_ns (HTML_NS, 'aside');
      $ad_el->set_attribute (class => 'swe-ad');
      $ad_el->inner_html (q[
        <script>
          google_ad_client = "pub-6943204637055835";
          google_ad_slot = "4290129344";
          google_ad_width = 728;
          google_ad_height = 90;
        </script>
        <script src="http://pagead2.googlesyndication.com/pagead/show_ads.js">
        </script>
      ]);
      $body_el->append_child ($ad_el);

      my $footer_el = $html_doc->create_element_ns (HTML_NS, 'footer');
      $footer_el->set_attribute (class => 'footer');
      $footer_el->inner_html (q[<p class=copyright><small>&copy; Authors.  See <a rel=license>license terms</a>.  There might also be additional terms applied for this page.</small>]);
      $body_el->append_child ($footer_el);
      
      my $a_el = $footer_el->get_elements_by_tag_name ('a')->[0];
      our $license_name;
      $a_el->set_attribute (href => get_page_url ($license_name));

      set_foot_content ($html_doc);
      
      binmode STDOUT, ':encoding(utf-8)';
      print qq[Content-Type: text/html; charset=utf-8\n\n];
      print $html_doc->inner_html;
      exit;
    }

    exit;
  } elsif ($param eq 'history' and not defined $dollar) {
    my $name_history_db = $db->name_history;
    my $history = $name_history_db->get_data ($name);

    binmode STDOUT, ':encoding(utf-8)';
    print "Content-Type: text/html; charset=utf-8\n\n";

    my $doc = $dom->create_document;
    $doc->manakai_is_html (1);
    $doc->inner_html (q[<!DOCTYPE HTML><html lang=en><title></title><h1></h1>
<div class=section><h2>History</h2><table>

<thead>
<tr><th scope=col>Time<th scope=col>Change

<tbody>
                        
</table></div>]);
    set_head_content ($doc, undef, [], []);

    my $title_el = $doc->get_elements_by_tag_name ('title')->[0];
    $title_el->inner_html ('History &mdash; ');
    $title_el->manakai_append_text ($name);
    
    my $h1_el = $doc->get_elements_by_tag_name ('h1')->[0];
    $h1_el->text_content ($name);
    
    my $table_el = $doc->get_elements_by_tag_name ('table')->[0];
    if ($history) {
      my $tbody_el = $table_el->last_child;

      for my $entry (@$history) {
        my $tr_el = $doc->create_element_ns (HTML_NS, 'tr');
        
        my $date_cell = $doc->create_element_ns (HTML_NS, 'td');
        my $date = gmtime ($entry->[0] || 0); ## TODO: ...
        $date_cell->inner_html ('<time>' . $date . '</time>');
        $tr_el->append_child ($date_cell);

        my $change_cell = $doc->create_element_ns (HTML_NS, 'td');
        if ($entry->[1] eq 'c') {
          $change_cell->manakai_append_text ('Created');
        } elsif ($entry->[1] eq 'a') {
          $change_cell->manakai_append_text ('Associated with ');
          my $a_el = $doc->create_element_ns (HTML_NS, 'a');
          $a_el->set_attribute (href => '../i/' . $entry->[2] . ';history');
          $a_el->text_content ($entry->[2]);
          $change_cell->append_child ($a_el);
        } elsif ($entry->[1] eq 'r') {
          $change_cell->manakai_append_text ('Disassociated from ');
          my $a_el = $doc->create_element_ns (HTML_NS, 'a');
          $a_el->set_attribute (href => '../i/' . $entry->[2] . ';history');
          $a_el->text_content ($entry->[2]);
          $change_cell->append_child ($a_el);
        } elsif ($entry->[1] eq 't') {
          $change_cell->manakai_append_text
              ('Converted from SuikaWiki3 database');
        } else {
          $change_cell->manakai_append_text ($entry->[1]);
        }
        $tr_el->append_child ($change_cell);

        $tbody_el->append_child ($tr_el);
      }
    } else {
      my $p_el = $doc->create_element_ns (HTML_NS, 'p');
      $p_el->text_content ('No history data.');
      $table_el->parent_node->replace_child ($p_el, $table_el);
    }

    set_foot_content ($doc);

    print $doc->inner_html;
    exit;
  } elsif ($param eq 'search' and not defined $dollar) {
    my $names = [];
    for_unique_words ($name => sub {
      push @$names, shift;
    });

    my $names_index_db = $db->name_inverted_index;
    my $index = {};
    {
      my $name = shift @$names;
      last unless defined $name;
      $index = $names_index_db->get_data ($name);
    }

    ## TOOD: "NOT" operation

    for my $name (@$names) {
      my $ids = $names_index_db->get_data ($name);
      my @index = keys %$index;
      for my $id (@index) {
        delete $index->{$id} unless $ids->{$id};
      }
      for my $id (keys %$ids) {
        if (defined $index->{$id}) {
          $index->{$id} *= $ids->{$id};
        }
      }
    }
    
    binmode STDOUT, ':encoding(utf-8)';
    print "Content-Type: text/plain; charset=utf-8\n\n";
    
    for my $id (sort {$index->{$b} <=> $index->{$a}} keys %$index) {

      my $id_prop = $id_prop_db->get_data ($id);
      my $name = [keys %{$id_prop->{name}}]->[0] // $id;

      print $index->{$id}, "\t", $id, "\t", $name, "\n";
    }
    exit;
  } elsif ($param eq 'posturl') {
    my ($id, undef) = prepare_by_name ($name, $dollar);

    if (defined $dollar and not defined $id) {
      http_error (404, 'Not found');
    }

    if ($cgi->request_method eq 'POST') {
      my $user = '(anon)'; #$cgi->remote_user // '(anon)';
      my $added_text = '<' . ($cgi->get_parameter ('url') // '') . '>';
      {
        my $credit = $cgi->get_parameter ('credit') // '';
        $added_text = '(' . $credit . ")\n" . $added_text if length $credit;

        my $timestamp = $cgi->get_parameter ('timestamp') // '';
        if (length $timestamp) {
          $added_text = '(Referenced: [TIME[' . $timestamp . "]])\n". $added_text;
        }

        my $title = $cgi->get_parameter ('title') // '';
        if (length $title) {
          $title =~ s/(\[|\])/'''$1'''/g;
          my $tl = $cgi->get_parameter ('title-lang') // '';
          if (length $tl) {
            $title = '[CITE@' . $tl . '[' . $title . ']]';
          } else {
            $title = '[CITE[' . $title . ']]';
          }
          $added_text = $title . "\n" . $added_text;
        }
      }
      normalize_content (\$added_text);

      my $anchor = 1;
      APPEND: { if (defined $id) { ## Existing document
        ## This must be done before the ID lock.
        $db->name_inverted_index->lock;

        my $id_lock = $id_locks->get_lock ($id);
        $id_lock->lock;
        
        my $id_prop = $id_prop_db->get_data ($id);
        last APPEND unless $id_prop;
        last APPEND if $id_prop->{'content-type'} ne 'text/x-suikawiki';
        
        my $textref = $content_db->get_data ($id);
        my $max = 0;
        while ($$textref =~ /\[([0-9]+)\]/g) {
          $max = $1 if $max < $1;
        }
        $max++;
        $$textref .= "\n\n[$max] " . $added_text;
        $anchor = $max;
        
        $id_prop->{modified} = time;
        $id_prop->{hash} = get_hash ($textref);
        
        my $vc = $db->vc;
        local $content_db->{version_control} = $vc;
        local $id_prop_db->{version_control} = $vc;
        
        $content_db->set_data ($id => $textref);
        $id_prop_db->set_data ($id => $id_prop);
        
        $vc->commit_changes ("updated by $user");

        ## TODO: non-default content-type support
        my $cache_prop = $cache_prop_db->get_data ($id);
        my $doc = $id_prop ? get_xml_data ($id, $id_prop, $cache_prop) : undef;
          
        if (defined $doc) {
          update_tfidf ($id, $doc);
        }

        if ($cgi->get_parameter ('redirect')) {
          http_redirect (303, 'Appended', get_page_url ($name, undef, $id) . '#anchor-' . $anchor);
        } else {
          print qq[Status: 204 Appended\n\n];
        }
        exit;
      }} # APPEND

      { ## New document
        my $new_names = {$name => 1};
        my $content = '[1] ' . $added_text;

        $names_lock->lock;
        my $time = time;
        
        require SWE::Object::Document;
        my $document = SWE::Object::Document->new_id (db => $db);
        $document->{name_prop_db} = $name_prop_db; ## TODO: ...
        $document->{sw3_pages} = $sw3_pages; ## TODO: ...
        
        my $id = $document->id;
        
        {
          ## This must be done before the ID lock.
          $db->name_inverted_index->lock;
          
          my $id_lock = $id_locks->get_lock ($id);
          $id_lock->lock;
          
          my $vc = $db->vc;
          local $content_db->{version_control} = $vc;
          local $id_prop_db->{version_control} = $vc;
          $vc->add_file ($db->id->{file_name});
          
          my $id_history_db = $db->id_history;
          local $id_history_db->{version_control} = $vc;
          
          $content_db->set_data ($id => \$content);
          
          my $id_props = {};
          
          $id_history_db->append_data ($id => [$time, 'c']);
          $id_props->{modified} = $time;
          
          for (keys %$new_names) {
            $id_props->{name}->{$_} = 1;
            $id_history_db->append_data ($id => [$time, 'a', $_]);
          }
          
          $id_props->{'content-type'} = 'text/x-suikawiki';
          $id_props->{hash} = get_hash (\$content);
          $id_prop_db->set_data ($id => $id_props);
          
          $vc->commit_changes ("created by $user");
          
          ## TODO: non-default content-type support
          my $cache_prop = $cache_prop_db->get_data ($id);
          my $doc = $id_props ? get_xml_data ($id, $id_props, $cache_prop) : undef;
          
          if (defined $doc) {
            $document->update_tfidf ($doc);
          }
          
          $id_lock->unlock;
        }

        $document->associate_names ($new_names, user => $user, time => $time);

        if ($cgi->get_parameter ('redirect')) {
          http_redirect (303, 'Appended', get_page_url ($name, undef, $id) . '#anchor-' . $anchor);
          exit;
        } else {
          print qq[Status: 204 Appended\n\n];
        }
        exit;
      }
    } else {
      http_error (405, 'Method not allowed', 'POST');
    }
  } else {
    $name .= '$' . $dollar if defined $dollar;
    $name .= ';' . $param;
    http_redirect (301, 'Not found', get_page_url ($name, undef));
    exit;
  }
} elsif ($path[0] eq 'i' and @path == 2 and not defined $dollar) {
  unless (defined $param) {
    if ($cgi->request_method eq 'POST' or
        $cgi->request_method eq 'PUT') {
      my $id = $path[1] + 0;
      
      ## This must be done before the ID lock.
      $db->name_inverted_index->lock;

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

        my $title = $cgi->get_parameter ('title');
        if (defined $title) {
          normalize_content (\$title);
          $id_prop->{title} = $title;
          $id_prop->{'title-type'} = 'text/plain'; ## TODO: get_parameter
        }

        my $vc = $db->vc;
        local $content_db->{version_control} = $vc;
        local $id_prop_db->{version_control} = $vc;
        
        $content_db->set_data ($id => $textref);
        $id_prop_db->set_data ($id => $id_prop);

        my $user = '(anon)'; #$cgi->remote_user // '(anon)';
        $vc->commit_changes ("updated by $user");

        ## TODO: non-default content-type support
        my $cache_prop = $cache_prop_db->get_data ($id);
        my $doc = $id_prop ? get_xml_data ($id, $id_prop, $cache_prop) : undef;

        if (defined $doc) {
          update_tfidf ($id, $doc);
        }

        my $url = get_page_url ([keys %{$id_prop->{name} or {}}]->[0],
                                undef, 0 + $id);
        print "X-SW-Hash: $id_prop->{hash}\n";
        if ($cgi->get_parameter ('no-redirect')) {
          http_redirect (201, 'Saved', $url);
        } else {
          http_redirect (301, 'Saved', $url);
        }
        exit;
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

      require SWE::Object::Document;
      my $doc = SWE::Object::Document->new (db => $db, id => $id);

      my $id_prop = $id_prop_db->get_data ($id);
      my $names = $id_prop->{name} || {};
      my $hash = $id_prop->{hash} // get_hash ($textref);

      my $custom_edit = '';
      if ($doc->content_media_type eq 'image/x-canvas-instructions+text') {
        my $request_uri = $cgi->request_uri;
        my $source_url = get_absolute_url (get_page_url ([keys %$names]->[0], undef, $id) . '?format=text', $request_uri);
        my $post_url = get_absolute_url ($id, $request_uri);
        my $url = 'http://suika.fam.cx/swe/pages/canvas?input-url=' . percent_encode ($source_url) . ';post-url=' . percent_encode($post_url);
        $custom_edit = q[<a href="].$url.q[">Edit image</a>];

        $post_url = get_absolute_url ('../new-page', $request_uri);
        $url = 'http://suika.fam.cx/swe/pages/canvas?input-url=' . percent_encode ($source_url) . ';post-url=' . percent_encode($post_url);
        $custom_edit .= q[ <a href="].$url.q[">Clone image</a>];
      }
      
      ## TODO: <select name=title-type>
      my $html_doc = $dom->create_document;
      $html_doc->manakai_is_html (1);
      $html_doc->inner_html (q[<!DOCTYPE HTML><title>Edit</title>
<h1>Edit</h1>
<div class="nav swe-names"></div>

<div class=section>
<h2>Page</h2>

].$custom_edit.q[

<form method=post accept-charset=utf-8>
<p><button type=submit>Update</button>
<p><label><strong>Page title</strong>:<br>
<input name=title></label>
<p><label for=page-body-text><strong>Page body</strong></label>:
<span class=text-toolbar></span><br>
<textarea name=text id=page-body-text></textarea>
<p><button type=submit>Update</button>
<input type=hidden name=hash>
<select name=content-type></select>
[<a rel=help>Help</a> / <a rel=license>License</a>]
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
      set_head_content ($html_doc, $id, [],
                        [{name => 'ROBOTS', content => 'NOINDEX'}]);
      my $form_el = $html_doc->get_elements_by_tag_name ('form')->[0];
      $form_el->set_attribute (action => $id);
      my $ta_el = $form_el->get_elements_by_tag_name ('textarea')->[0];
      $ta_el->text_content ($$textref);

      my $title_field = $form_el->get_elements_by_tag_name ('input')->[0];
      $title_field->set_attribute (value => $id_prop->{title} // '');

      my $hash_field = $form_el->get_elements_by_tag_name ('input')->[1];
      $hash_field->set_attribute (value => $hash);

      my $ct = $id_prop->{'content-type'} // 'text/x-suikawiki';
      set_content_type_options
          ($html_doc,
           $form_el->get_elements_by_tag_name ('select')->[0] => $ct);

      my $a_el = $form_el->get_elements_by_tag_name ('a')->[0];
      our $help_page_name;
      $a_el->set_attribute (href => get_page_url ($help_page_name));

      $a_el = $form_el->get_elements_by_tag_name ('a')->[1];
      our $license_name;
      $a_el->set_attribute (href => get_page_url ($license_name));

      $form_el = $html_doc->get_elements_by_tag_name ('form')->[1];
      $form_el->set_attribute (action => $id . ';names');
      
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

      set_foot_content ($html_doc);
     
      print $html_doc->inner_html;
      exit;
    }
  } elsif ($param eq 'names') {
    if ($cgi->request_method eq 'POST' or
        $cgi->request_method eq 'PUT') {
      my $id = $path[1] + 0;

      my $vc = $db->vc;
      local $name_prop_db->{version_control} = $vc;
      local $id_prop_db->{version_control} = $vc;
      
      my $id_history_db = $db->id_history;
      local $id_history_db->{version_control} = $vc;

      my $names_history_db = $db->name_history;
      local $names_history_db->{version_control} = $vc;

      my $time = time;

      $names_lock->lock;
      
      my $id_prop = $id_prop_db->get_data ($id);
      my $old_names = $id_prop->{name} || {};
      
      my $new_names = {};
      for (split /\x0D\x0A?|\x0A/, $cgi->get_parameter ('names')) {
        $new_names->{normalize_name ($_)} = 1;
      }
      delete $new_names->{''};
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
          unless (defined $new_name_prop) {
            $names_history_db->append_data ($new_name => [$time, 'c']);
          }
        }
        $new_name_prop->{name} = $new_name;
        push @{$new_name_prop->{id} ||= []}, $id;
        $name_prop_db->set_data ($new_name => $new_name_prop);

        $id_history_db->append_data ($id => [$time, 'a', $new_name]);
        $names_history_db->append_data ($new_name => [$time, 'a', $id]);
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

        $id_history_db->append_data ($id => [$time, 'r', $removed_name]);
        $names_history_db->append_data ($removed_name => [$time, 'r', $id]);
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
  } elsif ($param eq 'neighbors') {
    require SWE::Object::Repository;
    my $repo = SWE::Object::Repository->new (db => $db);

    my $graph = $repo->graph;
    $graph->lock;
    
    my $id = $path[1] + 0;
    my $doc = $repo->get_document_by_id ($id);
    $doc->lock;
    
    my $node = $doc->get_or_create_graph_node;
    
    if ($node) {
      binmode STDOUT, ':encoding(utf-8)';
      print "Content-Type: text/plain; charset=UTF-8\n\n";
      
      for my $doc (@{$node->neighbor_documents}) {
        print join "\t", $doc->id, $doc->name;
        print "\n";
      }
      
      close STDOUT;
      
      $graph->schelling_update ($node->id);

      $doc->unlock;
      $graph->unlock;
      
      exit;
    } else {
      $doc->unlock;
      $graph->unlock;
      #
    }
  } elsif ($param eq 'history' and not defined $dollar) {
    my $id = $path[1] + 0;

    my $id_history_db = $db->id_history;
    my $history = $id_history_db->get_data ($id);

    binmode STDOUT, ':encoding(utf-8)';
    print "Content-Type: text/html; charset=utf-8\n\n";

    my $doc = $dom->create_document;
    $doc->manakai_is_html (1);
    $doc->inner_html (q[<!DOCTYPE HTML><html lang=en><title></title><h1></h1>
<div class=section><h2>History</h2><table>

<thead>
<tr><th scope=col>Time<th scope=col>Change

<tbody>
                        
</table></div>]);
    set_head_content ($doc, undef, [], []);

    my $title_el = $doc->get_elements_by_tag_name ('title')->[0];
    $title_el->inner_html ('History &mdash; #');
    $title_el->manakai_append_text ($id);
    
    my $h1_el = $doc->get_elements_by_tag_name ('h1')->[0];
    $h1_el->text_content ('#' . $id);
    
    my $table_el = $doc->get_elements_by_tag_name ('table')->[0];
    if ($history) {
      my $tbody_el = $table_el->last_child;

      for my $entry (@$history) {
        my $tr_el = $doc->create_element_ns (HTML_NS, 'tr');
        
        my $date_cell = $doc->create_element_ns (HTML_NS, 'td');
        my $date = gmtime ($entry->[0] || 0); ## TODO: ...
        $date_cell->inner_html ('<time>' . $date . '</time>');
        $tr_el->append_child ($date_cell);

        my $change_cell = $doc->create_element_ns (HTML_NS, 'td');
        if ($entry->[1] eq 'c') {
          $change_cell->manakai_append_text ('Created');
        } elsif ($entry->[1] eq 'a') {
          $change_cell->manakai_append_text ('Associated with ');
          my $a_el = $doc->create_element_ns (HTML_NS, 'a');
          $a_el->set_attribute (href => get_page_url ($entry->[2], undef)
                                    . ';history');
          $a_el->text_content ($entry->[2]);
          $change_cell->append_child ($a_el);
        } elsif ($entry->[1] eq 'r') {
          $change_cell->manakai_append_text ('Disassociated from ');
          my $a_el = $doc->create_element_ns (HTML_NS, 'a');
          $a_el->set_attribute (href => get_page_url ($entry->[2], undef)
                                    . ';history');
          $a_el->text_content ($entry->[2]);
          $change_cell->append_child ($a_el);
        } elsif ($entry->[1] eq 't') {
          $change_cell->manakai_append_text
              ('Converted from SuikaWiki3 database');
        } else {
          $change_cell->manakai_append_text ($entry->[1]);
        }
        $tr_el->append_child ($change_cell);

        $tbody_el->append_child ($tr_el);
      }
    } else {
      my $p_el = $doc->create_element_ns (HTML_NS, 'p');
      $p_el->text_content ('No history data.');
      $table_el->parent_node->replace_child ($p_el, $table_el);
    }

    set_foot_content ($doc);

    print $doc->inner_html;
    exit;
  } elsif ($param eq 'terms' and not defined $dollar) {
    my $id = $path[1] + 0;

    ## This must be done before the ID lock.
    $db->name_inverted_index->lock;
    
    my $id_lock = $id_locks->get_lock ($id);
    $id_lock->lock;
    
    my $id_prop = $id_prop_db->get_data ($id);
    my $cache_prop = $cache_prop_db->get_data ($id);
    my $doc = $id_prop ? get_xml_data ($id, $id_prop, $cache_prop) : undef;

    if (defined $doc) {
      update_tfidf ($id, $doc);

      $id_lock->unlock;

      binmode STDOUT, ':encoding(utf-8)';
      print "Content-Type: text/plain; charset=utf-8\n\n";

      print ${ $db->id_tfidf->get_data ($id) };
      
      exit;
    } else {
      $id_lock->unlock;
    }
  } elsif ($param =~ /^(un)?related-([0-9]+)$/ and not defined $dollar) {
    ## Allow GET to not require Basic auth.
    #if ($cgi->request_method eq 'POST') {
      my $id1 = $path[1] + 0;
      my $id2 = $2 + 0;
      my $answer = $1 ? -1 : 1;
      
      require SWE::Object::Repository;
      my $repo = SWE::Object::Repository->new (db => $db);

      my $vc = $db->vc;
      
      $repo->weight_lock;
      local $db->global_prop->{version_control} = $vc;
      my $y = $repo->are_related_ids ($id1, $id2, $answer);
      $repo->save_term_weight_vector;
      $vc->commit_changes ('term weight vector update');
      $repo->weight_unlock;
      
      print "Content-Type: text/ping\n\n";
      print "PING";
      exit;
    #} else {
    #  http_error (405, 'Method not allowed', 'POST');
    #}
  }
} elsif ($path[0] eq 'new-page' and @path == 1) {
  if ($cgi->request_method eq 'POST') {
    my $new_names = {};
    for (split /\x0D\x0A?|\x0A/, scalar $cgi->get_parameter ('names')) {
      $new_names->{normalize_name ($_)} = 1;
    }
    delete $new_names->{''};
    $new_names->{'(no title)'} = 1 unless keys %$new_names;

    my $user = '(anon)'; #$cgi->remote_user // '(anon)';
    my $ct = get_content_type_parameter ();

    my $content = $cgi->get_parameter ('text') // '';
    normalize_content (\$content);

    $names_lock->lock;
    my $time = time;

    require SWE::Object::Document;
    my $document = SWE::Object::Document->new_id (db => $db);
    $document->{name_prop_db} = $name_prop_db; ## TODO: ...
    $document->{sw3_pages} = $sw3_pages; ## TODO: ...

    my $id = $document->id;
    my $id_prop = {};

    {
      ## This must be done before the ID lock.
      $db->name_inverted_index->lock;

      my $id_lock = $id_locks->get_lock ($id);
      $id_lock->lock;

      my $vc = $db->vc;
      local $content_db->{version_control} = $vc;
      local $id_prop_db->{version_control} = $vc;
      $vc->add_file ($db->id->{file_name});
      
      my $id_history_db = $db->id_history;
      local $id_history_db->{version_control} = $vc;

      $content_db->set_data ($id => \$content);

      $id_history_db->append_data ($id => [$time, 'c']);
      $id_prop->{modified} = $time;
      
      for (keys %$new_names) {
        $id_prop->{name}->{$_} = 1;
        $id_history_db->append_data ($id => [$time, 'a', $_]);
      }

      $id_prop->{'content-type'} = $ct;
      $id_prop->{hash} = get_hash (\$content);
      $id_prop->{title} = $cgi->get_parameter ('title') // '';
      normalize_content (\($id_prop->{title}));
      $id_prop->{'title-type'} = 'text/plain'; ## TODO: get_parameter
      $id_prop_db->set_data ($id => $id_prop);

      $vc->commit_changes ("created by $user");

      ## TODO: non-default content-type support
      my $cache_prop = $cache_prop_db->get_data ($id);
      my $doc = $id_prop ? get_xml_data ($id, $id_prop, $cache_prop) : undef;
      
      if (defined $doc) {
        $document->update_tfidf ($doc);
      }
      
      $id_lock->unlock;
    }

    $document->associate_names ($new_names, user => $user, time => $time);
    
    print "X-SW-Hash: $id_prop->{hash}\n";
    
    my $post_url = get_absolute_url ("i/$id", $cgi->request_uri);
    print "X-SW-Post-URL: $post_url\n";

    my $url = get_page_url ([keys %$new_names]->[0], undef, 0 + $id);
    if ($cgi->get_parameter ('no-redirect')) {
      http_redirect (201, 'Created', $url);
    } else {
      http_redirect (301, 'Created', $url);
    }
    exit;
  } else {
    binmode STDOUT, ':encoding(utf8)';
    print "Content-Type: text/html; charset=utf-8\n\n";

    my $custom_edit = '';
    my $request_uri = $cgi->request_uri;
    my $post_url = get_absolute_url ('new-page', $request_uri);
    my $names = $cgi->get_parameter ('names') // '';
    my $url = 'http://suika.fam.cx/swe/pages/canvas?post-url=' . percent_encode($post_url) . ';names=' . percent_encode ($names);
    $custom_edit = q[<a href="].$url.q[">Image</a>];

    ## TODO: select name=title-type
    my $doc = $dom->create_document;
    $doc->manakai_is_html (1);
    $doc->inner_html (q[<!DOCTYPE HTML><title>New page</title>
<h1>New page</h1>
].$custom_edit.q[
<form action=new-page method=post accept-charset=utf-8>
<p><button type=submit>Save</button>
<p><label><strong>Page name(s)</strong>:<br>
<textarea name=names></textarea></label>
<p><label><strong>Page title</strong>:<br>
<input name=title></label>
<p><label for=page-body-text><strong>Page body</strong></label>:
<span class=text-toolbar></span><br>
<textarea name=text id=page-body-text></textarea>
<p><button type=submit>Save</button>
<select name=content-type></select>
[<a rel=help>Help</a> / <a rel=license>License</a>]
</form>
]);
    set_head_content ($doc, undef, [],
                      [{name => 'ROBOTS', content => 'NOINDEX'}]);

    my $form_el = $doc->get_elements_by_tag_name ('form')->[0];
    set_content_type_options
        ($doc, $form_el->get_elements_by_tag_name ('select')->[0]);

    my $names = $cgi->get_parameter ('names') // '';
    $form_el->get_elements_by_tag_name ('textarea')->[0]
        ->text_content ($names);

    my $a_el = $form_el->get_elements_by_tag_name ('a')->[0];
    our $help_page_name;
    $a_el->set_attribute (href => get_page_url ($help_page_name));

    $a_el = $form_el->get_elements_by_tag_name ('a')->[1];
    our $license_name;
    $a_el->set_attribute (href => get_page_url ($license_name));
    
    set_foot_content ($doc);

    print $doc->inner_html;
    exit;
  }
} elsif (@path == 1 and
         {'' => 1, 'n' => 1, 'i' => 1}->{$path[0]}) {
  our $homepage_name;
  http_redirect (303, 'See other', get_page_url ($homepage_name, undef));
  exit;
} elsif (@path == 0) {
  my $rurl = $cgi->request_uri;
  $rurl =~ s!\.[^/]*$!!g;
  http_redirect (303, 'See other', $rurl . '/');
  exit;
}

http_error (404, 'Not found');

sub prepare_by_name ($$) {
  my ($name, $id_cand) = @_;
  
  my $ids = get_ids_by_name ($name);
  unless (ref $ids) {
    $names_lock->lock;
    $sw3_pages->reset;

    $ids = convert_sw3_page ($ids => $name);
    $names_lock->unlock;
  }

  my $id;
  if (defined $id_cand) {
    $id_cand += 0;
    for (0..$#$ids) {
      if ($ids->[$_] == $id_cand) {
        $id = $id_cand;
        splice @$ids, $_, 1, ();
        last;
      }
    }
  } else {
    $id = shift @$ids;
  }
  
  return ($id, $ids);
} # prepare_by_name

sub get_content_type_parameter () {
  my $ct = $cgi->get_parameter ('content-type') // 'text/x-suikawiki';
  
  my $valid_ct;
  for (@ContentMediaType) {
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
  for (@ContentMediaType) {
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

  our $style_url;

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
  
  my $abs_url = get_absolute_url ($url, $cgi->request_uri);

  binmode STDOUT, ':encoding(utf-8)';
  print qq[Status: $code $text
Location: $abs_url
Content-Type: text/html; charset=utf-8

<!DOCTYPE HTML>
<html lang=en>
<title>$code @{[htescape ($text)]}</title>
<h1>@{[htescape ($text)]}</h1>
<p>See <a href="@{[htescape ($url)]}">other page</a>.];
} # http_redirect

sub normalize_name ($) {
  my $s = shift;
  Char::Normalize::FullwidthHalfwidth::normalize_width (\$s);
  $s =~ s/\s+/ /g;
  $s =~ s/^ //;
  $s =~ s/ $//;
  return $s;
} # normalize_name

sub normalize_content ($) {
  my $sref = shift;
  Char::Normalize::FullwidthHalfwidth::normalize_width ($sref);
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

sub get_xml_data ($$$) {
  my ($id, $id_prop, $cache_prop) = @_;

  my $cached_hash = $cache_prop->{'cached-hash'};

  if ($cached_hash) {
    my $content_hash = $id_prop->{hash} || '';
    
    if ($cached_hash ne $content_hash) {
      undef $cached_hash;
    }
  }

  state $content_cache_db;
  unless (defined $content_cache_db) {
    require SWE::DB::IDDOM;
    $content_cache_db = SWE::DB::IDDOM->new;
    $content_cache_db->{root_directory_name} = $db_id_dir_name;
    $content_cache_db->{leaf_suffix} = '.domcache';
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

sub for_unique_words ($*) {
  #my ($string, $code) = @_;
  
  ## TODO: use mecab

  require Text::Kakasi;
  my $k = Text::Kakasi->new;
  
  ## TODO: support stop words
  
  my $all_terms = 0;
  my $terms = {};
  for my $term (split /\s+/, $k->set (qw/-iutf8 -outf8 -w/)->get ($_[0])) {

    ## TODO: provide a way to save original representation

    ## TODO: more normalization
    $term = lc $term;

    $terms->{$term}++;
  }
  
  for my $term (keys %$terms) {
    $_[1]->($term, $terms->{$term});
  }
} # for_unique_words

## TODO: This function is OBSOLETE!
sub update_tfidf ($$) {
  my ($id, $doc) = @_;

  require SWE::Object::Document;
  my $document = SWE::Object::Document->new (db => $db, id => $id);
  $document->{name_prop_db} = $name_prop_db; ## TODO: ...
  $document->{sw3_pages} = $sw3_pages; ## TODO: ...
  
  $document->update_tfidf ($doc);
} # update_tfidf

sub convert_sw3_page ($$) {
  my ($sw3key => $name) = @_;
  
  my $page_key = $sw3_pages->get_data ($name);
      ## NOTE: $page_key is undef if the page has been converted
      ## between the first (in get_ids_by_name) and the second (the
      ## line above) $sw3_pages->get_data calls.

  my $ids;
  if (defined $page_key) {
    my $idgen = $db->id;
    my $time = time;
    
    my $id = $idgen->get_next_id;
    my $id_lock = $id_locks->get_lock ($id);
    $id_lock->lock;

    my $vc = $db->vc;
    local $content_db->{version_control} = $vc;
    local $id_prop_db->{version_control} = $vc;
    $vc->add_file ($idgen->{file_name});

    my $id_history_db = $db->id_history;
    local $id_history_db->{version_control} = $vc;
    
    our $sw3_db_dir_name;
    
    state $sw3_content_db;
    unless (defined $sw3_content_db) {
      require SWE::DB::SuikaWiki3;
      $sw3_content_db = SWE::DB::SuikaWiki3->new;
      $sw3_content_db->{root_directory_name} = $sw3_db_dir_name;
    }
    
    state $sw3_prop_db;
    unless (defined $sw3_prop_db) {
      require SWE::DB::SuikaWiki3Props;
      $sw3_prop_db = SWE::DB::SuikaWiki3Props->new;
      $sw3_prop_db->{root_directory_name} = $sw3_db_dir_name;
    }
    
    state $sw3_lm_db;
    unless (defined $sw3_lm_db) {
      require SWE::DB::SuikaWiki3LastModified;
      $sw3_lm_db = SWE::DB::SuikaWiki3LastModified->new;
      $sw3_lm_db->{file_name} = $sw3_db_dir_name .
          'mt--6C6173745F6D6F646966696564.dat';
    }

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

    $id_history_db->append_data ($id => [$time, 't']);
    $id_history_db->append_data ($id => [$time, 'a', $name]);

    $vc->commit_changes ("converted from SuikaWiki3 <http://suika.fam.cx/gate/cvs/suikawiki/wikidata/page/$page_key.txt>");

    $id_lock->unlock;

    $vc = $db->vc;
    local $name_prop_db->{version_control} = $vc;
    local $sw3_pages->{version_control} = $vc;
    
    my $names_history_db = $db->name_history;
    local $names_history_db->{version_control} = $vc;
    
    my $name_props = $name_prop_db->get_data ($name);
    push @{$name_props->{id} ||= []}, $id;
    $ids = $name_props->{id};
    $name_props->{name} = $name;
    $name_prop_db->set_data ($name => $name_props);

    $names_history_db->append_data ($name => [$time, 't']);
    $names_history_db->append_data ($name => [$time, 'a', $id]);

    $sw3_pages->delete_data ($name);
    $sw3_pages->save_data;
    
    $vc->commit_changes ("converted from SuikaWiki3 <http://suika.fam.cx/gate/cvs/suikawiki/wikidata/page/$page_key.txt>");
  } else {
    my $name_props = $name_prop_db->get_data ($name);
    $ids = $name_props->{id};
  }

  return $ids;
} # convert_sw3_page

sub set_head_content ($;$$$) {
  my ($doc, $id, $links, $metas) = @_;
  my $head_el = $doc->manakai_head;

  our $license_name;
  our $style_url;
  push @{$links ||= []}, {rel => 'stylesheet', href => $style_url},
      {rel => 'license', href => get_page_url ($license_name, undef)};
  
  if (defined $id) {
    our $cvs_archives_url;
    push @$links, {rel => 'archives',
                   href => $cvs_archives_url . 'ids/' .
                             int ($id / 1000) . '/' . ($id % 1000) . '.txt',
                   title => 'CVS log for the page content'};
  }
  
  for my $item (@$links) {
    my $link_el = $doc->create_element_ns (HTML_NS, 'link');
    for (keys %$item) {
      $link_el->set_attribute ($_ => $item->{$_});
    }
    $head_el->append_child ($link_el);
  }

  for my $item (@{$metas or []}) {
    my $meta_el = $doc->create_element_ns (HTML_NS, 'meta');
    $meta_el->set_attribute (name => $item->{name} // '');
    $meta_el->set_attribute (content => $item->{content} // '');
    $head_el->append_child ($meta_el);
  }
} # set_head_content

sub set_foot_content ($) {
  my $doc = shift;

  my $body_el = $doc->last_child->last_child;

  our $script_url;
  my $script_el = $doc->create_element_ns (HTML_NS, 'script');
  $script_el->set_attribute (src => $script_url);
  $body_el->append_child ($script_el);
} # set_foot_content

1; ## $Date: 2009/12/27 11:34:31 $
