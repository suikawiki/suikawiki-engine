package SuikaWiki5::Main;
use strict;
use SWE::String;
use Web::URL::Encoding;
use Web::DOM::Document;
use SWML::Parser;
use SWE::Lang qw/@ContentMediaType/;

sub main ($$) {
  my (undef, $app) = @_;

  my @path = @{$app->path_segments};
  my $db = $app->db;

if ($path[0] eq 'n' and @path == 2) {
  my $name = normalize_name ($path[1]);
  
  unless (length $name) {
    return $app->throw_redirect ($app->home_page_url, status => 303);
  }

  my $param = $app->path_param;
  unless (defined $param) {
    my ($id, $ids) = prepare_by_name ($db, $name, $app->path_dollar);

    if (defined $app->path_dollar and not defined $id) {
      return $app->throw_redirect
          ($app->name_url ($name),
           status => 301, reason_phrase => 'Not found');
    }

    my $format = $app->bare_param ('format') // 'html';
    
    require SWE::Object::Document;
    my $docobj = SWE::Object::Document->new (id => $id, db => $db);
    $docobj->rebless;

    if ($format eq 'text' and defined $id) {
      $docobj->{content_db} = $db->id_content;
      $docobj->{id_prop_db} = $db->id_prop;

      my $id_prop = $db->id_prop->get_data ($id);
      $app->http->add_response_header ('X-SW-Hash' => $id_prop->{hash});
      $app->http->add_response_header
          ('Content-Type' => $docobj->to_text_media_type . '; charset=utf-8');
      $app->http->add_response_header
          ('x-content-type-options', 'nosniff');
      my $modified = $id_prop->{modified};
      $app->http->set_response_last_modified ($modified) if $modified;
      $app->http->send_response_body_as_text (${$docobj->to_text});
      $app->http->close_response_body;
      return $app->throw;
    } elsif ($format eq 'xml' and defined $id) {
      ## XXX
      $docobj->{content_db} = $db->id_content;
      $docobj->{id_prop_db} = $db->id_prop;
      $docobj->{cache_prop_db} = $db->id_cache_prop;
      $docobj->{swml_to_xml} = \&get_xml_data;

      my $xmldoc = $docobj->to_xml
          (db => $db, styled => scalar $app->bare_param ('styled'));
      if ($xmldoc) {
        $app->http->add_response_header
            ('Content-Type' => $docobj->to_xml_media_type . '; charset=utf-8');
        $app->http->add_response_header
            ('content-security-policy', 'sandbox');
        my $id_prop = $db->id_prop->get_data ($id);
        $app->http->add_response_header ('X-SW-Hash' => $id_prop->{hash});
        my $modified = $id_prop->{modified};
        $app->http->set_response_last_modified ($modified) if $modified;
        $app->http->send_response_body_as_text ($xmldoc->inner_html);
        $app->http->close_response_body;
        return $app->throw;
      } else {
        return $app->throw_error
            (406, reason_phrase => q{format=xml is not supported for this page});
      }
    } elsif ($format eq 'html') {
      my $html_doc;
      my $html_container;
      my $title_text;
      my $id_prop;
      
      if (defined $id) {
        # XXX
        $docobj->{id_prop_db} = $db->id_prop;
        $docobj->{cache_prop_db} = $db->id_cache_prop;
        $docobj->{content_db} = $db->id_content;
        $docobj->{swml_to_xml} = \&get_xml_data;
        $docobj->{name} = $name;
        $docobj->{get_page_url} = sub {
          ## When this callback is modified,
          ## |$SWE::Lang::XML2HTML::ConverterVersion| must be
          ## incremented.
          return $app->name_url ($_[0]);
        };

        $docobj->lock;
        ($html_doc, $html_container) = $docobj->to_html_fragment (db => $db);

        $id_prop = $db->id_prop->get_data ($id);
        $title_text = $id_prop->{title};
        ## TODO: $title_type
        
        $docobj->unlock;
      }

      unless ($html_doc) {
        $html_doc = new Web::DOM::Document;
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
                     href => $app->name_url ($name, $id, format => 'text')};
      }

      my $xmt = $docobj->to_xml_media_type;
      if (defined $xmt) {
        push @link, {rel => 'alternate', type => $xmt,
                     href => $app->name_url ($name, $id, format => 'xml')};
      }
      
      push @link, {rel => 'archives',
                   href => $app->name_url ($name, undef, param => 'history'),
                   title => 'History of the page name'};
      if (defined $id) {
        push @link, {rel => 'archives',
                     href => $app->page_url ($id, param => 'history'),
                     title => 'History of the page ID'};
        push @link, {rel => 'archives',
                     href => $app->page_url ($id, param => 'datahistory'),
                     title => 'History of the page data'};
      }
      my @meta;
      push @meta, {name => 'ROBOTS', content => 'NOINDEX'} unless defined $id;
      push @meta, {name => 'viewport', content => 'width=device-width,initial-scale=1'};
      set_head_content ($app, \@path, $html_doc, $id, \@link, \@meta);
      
      my $body_el = $html_doc->last_child->last_child;

      $body_el->set_attribute ('data-historical' => '') if $id_prop->{historical};
      $body_el->set_attribute ('data-legal' => '') if $id_prop->{legal};
      $body_el->set_attribute ('data-sensitive' => '') if $id_prop->{sensitive};

      my $h1_el = $html_doc->create_element ('h1');
      my $a_el = $html_doc->create_element ('a');
      $a_el->set_attribute (href => $app->name_url ($name));
      $a_el->set_attribute (rel => 'bookmark');
      $a_el->text_content ($name);
      $h1_el->append_child ($a_el);
      $body_el->append_child ($h1_el);
      
      if (@$ids and not $name eq '(no title)') {
        my $nav_el = $html_doc->create_element ('div');
        $nav_el->set_attribute (class => 'nav swe-ids');
        $nav_el->manakai_append_text
            (@$ids == 1 ? 'There is another page with same name:'
                 : 'There are other pages with same name:');
        my $ul_el = $html_doc->create_element ('ul');
        for my $id (@$ids) {
          my $li_el = $html_doc->create_element ('li');
          $li_el->inner_html (q[<a></a>]);
          my $a_el = $li_el->first_child;
          my $id_prop = $db->id_prop->get_data ($id);
          $a_el->text_content
              (length $id_prop->{title} ? $id_prop->{title}
                 : [keys %{$id_prop->{name}}]->[0] // $id); ## TODO: title-type
          $a_el->set_attribute (href => $app->name_url ($name, $id));
          $ul_el->append_child ($li_el);
        }
        $nav_el->append_child ($ul_el);
        $body_el->append_child ($nav_el);
      }

      my $nav_el = $html_doc->create_element ('div');
      $nav_el->set_attribute (class => 'nav tools');
      $nav_el->inner_html (q[<a rel="edit nofollow">Edit</a> <a rel=nofollow>New</a>]);
      $nav_el->last_child->href ($app->page_create_url);
      if (defined $id) {
        $nav_el->first_child->set_attribute
            (href => $app->page_url ($id, param => 'edit'));
        $body_el->set_attribute ('data-doc-id' => $id);
      } else {
        $nav_el->first_child->set_attribute
            (href => $app->page_create_url ($name));
      }
      $body_el->append_child ($nav_el);

      my $modified;
      if ($html_container) {
        my $article_el = $html_doc->create_element ('div');
        $article_el->set_attribute (class => 'article');

        my $header = $html_doc->create_element ('header');
        $header->inner_html (q{
          <nav class=breadcrumb>
            <a href=https://suikawiki.org>SuikaWiki</a> >
            <a href=/>Wiki</a> >
          </nav>
          <h1></h1>
        });
        $header->last_element_child
            ->text_content (length $title_text ? $title_text : $name);
            ## TODO: {'title-type'};
        $article_el->append_child ($header);
        my $nav = $header->first_element_child;
        if (defined $id_prop->{parent}) {
          my $link = $html_doc->create_element ('a');
          $link->text_content ($id_prop->{parent});
          $link->set_attribute (href => '/n/' . percent_encode_c $id_prop->{parent});
          $nav->append_child ($link);
          my $text = $html_doc->create_text_node (' > ');
          $nav->append_child ($text);
        }
        {
          my $link = $html_doc->create_element ('a');
          $link->text_content (length $title_text ? $title_text : $name);
          $link->set_attribute (href => '');
          $nav->append_child ($link);
        }
        
        while (@{$html_container->child_nodes}) {
          $article_el->append_child ($html_container->first_child);
        }

        $modified = $id_prop->{modified};
        if (defined $modified) {
          my $footer_el = $html_doc->create_element ('div');
          $footer_el->set_attribute (class => 'footer swe-updated');
          $footer_el->inner_html ('Updated: <time></time>');
          my @time = gmtime $modified;
          $footer_el->last_child->text_content
              (sprintf '%04d-%02d-%02d %02d:%02d:%02d+00:00',
               $time[5] + 1900, $time[4] + 1, $time[3],
               $time[2], $time[1], $time[0]);
          $article_el->append_child ($footer_el);
        }
        
        $body_el->append_child ($article_el);
      } else {
        my $new_nav_el = $html_doc->create_element ('section');
        $new_nav_el->inner_html (q[<a href="">Add a description</a> of <em></em>]);
        $new_nav_el->last_child->text_content ($name);
        $new_nav_el->first_child->set_attribute
            (href => $app->page_create_url ($name));
        $body_el->append_child ($new_nav_el);
        $app->http->set_status (404);
      } # $html_container

      my $search_el = $html_doc->create_element ('div');
      $search_el->set_attribute (class => 'nav search');
      $search_el->set_attribute (id => 'cse-search-form');
      $body_el->append_child ($search_el);

      if ($html_container) {

        my $use_google_ads;
        my $modified = $id_prop->{modified};
        if (defined $modified and ((gmtime $modified)[5] + 1900) >= 2013) {
          $use_google_ads = 1;
        }
        $use_google_ads = 0 if $id_prop->{sensitive};

        if ($use_google_ads) {
          my $df = $html_doc->create_document_fragment;
          $df->inner_html (q{
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
<script>
  (adsbygoogle = window.adsbygoogle || []).push({
    google_ad_client: "ca-pub-6943204637055835",
    enable_page_level_ads: true
  });
</script>
          });
          $html_doc->head->append_child ($df);

          my $ad2_el = $html_doc->create_element ('aside');
          $ad2_el->set_attribute (class => 'swe-ad swe-ad-google');
          $ad2_el->inner_html (q{
<ins class="adsbygoogle"
     style="display:block"
     data-ad-client="ca-pub-6943204637055835"
     data-ad-slot="7192705117"
     data-ad-format="auto"></ins>
<script>
(adsbygoogle = window.adsbygoogle || []).push({});
</script>
          });
          $body_el->insert_before ($ad2_el, $search_el);

          my $grels_el = $html_doc->create_element ('div');
          $grels_el->set_attribute (class => 'swe-ad swe-ad-google');
          $grels_el->inner_html (q{
<ins class="adsbygoogle"
     style="display:block"
     data-ad-format="autorelaxed"
     data-ad-client="ca-pub-6943204637055835"
     data-ad-slot="2239220532"></ins>
<script>
     (adsbygoogle = window.adsbygoogle || []).push({});
</script>
          });
          $body_el->append_child ($grels_el);
        } else {
          #my $sidebar_el = $html_doc->create_element ('aside');
          #my $ad_el = $html_doc->create_element ('aside');
          #$ad_el->set_attribute (class => 'swe-ad swe-ad-amazon');
          #$ad_el->inner_html (q{<script>amazon_ad_tag = "wakaba1-22"; amazon_ad_width = "160"; amazon_ad_height = "600"; amazon_ad_logo = "hide"; amazon_ad_border = "hide"; amazon_color_border = "FFFFFF"; amazon_color_link = "004000"; amazon_color_logo = "004000";</script><script src="https://www.assoc-amazon.jp/s/ads.js"></script>});
          #$sidebar_el->append_child ($ad_el);
          #$body_el->class_list->add ('swe-has-sidebar');
        }

        my $ul_el = $html_doc->create_element ('ul');
        $ul_el->set_attribute (class => 'swe-page-names');
        for my $name (sort { (lc $a) cmp (lc $b) || $a cmp $b } keys %{$id_prop->{name} or {}}) {
          my $li_el = $html_doc->create_element ('li');
          $li_el->inner_html (q{<a href=""></a>});
          $li_el->first_child->text_content ($name);
          $li_el->first_child->href ($app->name_url ($name, $id));
          $ul_el->append_child ($li_el);
        }
        $body_el->append_child ($ul_el);

        {
          my $p_el = $html_doc->create_element ('nav');
          $p_el->class_name ('swe-page-links');
          my $a_el = $html_doc->create_element ('a');
          $a_el->href ($app->page_url ($id, param => 'datahistory'));
          $a_el->rel ('archives');
          $a_el->text_content ('History');
          $p_el->append_child ($a_el);
          $body_el->append_child ($p_el);
        }
      }

      my $footer_el = $html_doc->create_element ('footer');
      $footer_el->set_attribute (class => 'footer');
      $footer_el->set_attribute (lang => 'en');
      $footer_el->inner_html (q[
        <p class=copyright><small>&copy; Authors.  See <a rel=license>license terms (CC BY-SA / GFDL)</a>.  There might also be additional terms applied for this page.</small>
        <menu><a href="" rel=index>Home</a>
        <a href="">About</a>
        <a href="" rel=help>Help</a> <a href="">Contact</a></menu>
      ]);
      $body_el->append_child ($footer_el);

      my $as = $footer_el->get_elements_by_tag_name ('a');
      $as->[0]->set_attribute (href => $app->license_page_url);
      $as->[1]->set_attribute (href => $app->home_page_url);
      $as->[2]->set_attribute (href => $app->about_page_url);
      $as->[3]->set_attribute (href => $app->help_page_url);
      $as->[4]->set_attribute (href => $app->contact_page_url);

      set_foot_content ($app, $html_doc);

      $app->http->add_response_header
          ('Content-Type' => 'text/html; charset=utf-8');
      $app->http->add_response_header ('X-SW-Hash' => $id_prop->{hash})
          if defined $id;
      $app->http->set_response_last_modified ($modified) if $modified;
      $app->http->send_response_body_as_text ($html_doc->inner_html);
      $app->http->close_response_body;
      return $app->throw;
    }

  } elsif ($param eq 'history' and not defined $app->path_dollar) {
    my $name_history_db = $db->name_history;
    my $history = $name_history_db->get_data ($name);

    $app->http->add_response_header
        ('Content-Type' => 'text/html; charset=utf-8');

    my $doc = new Web::DOM::Document;
    $doc->manakai_is_html (1);
    $doc->inner_html (q[<!DOCTYPE HTML><html lang=en><title></title><h1></h1>
<div class=section><h2>History</h2><table>

<thead>
<tr><th scope=col>Time<th scope=col>Change

<tbody>
                        
</table></div>]);
    set_head_content ($app, \@path, $doc, undef, [], []);

    my $title_el = $doc->get_elements_by_tag_name ('title')->[0];
    $title_el->inner_html ('History &mdash; ');
    $title_el->manakai_append_text ($name);
    
    my $h1_el = $doc->get_elements_by_tag_name ('h1')->[0];
    $h1_el->text_content ($name);
    
    my $table_el = $doc->get_elements_by_tag_name ('table')->[0];
    if ($history) {
      my $tbody_el = $table_el->last_child;

      for my $entry (@$history) {
        my $tr_el = $doc->create_element ('tr');
        
        my $date_cell = $doc->create_element ('td');
        my @time = gmtime ($entry->[0] || 0);
        $date_cell->inner_html ('<time>' . (sprintf '%04d-%02d-%02d %02d:%02d:%02d+00:00',
               $time[5] + 1900, $time[4] + 1, $time[3],
               $time[2], $time[1], $time[0]) . '</time>');
        $tr_el->append_child ($date_cell);

        my $change_cell = $doc->create_element ('td');
        if ($entry->[1] eq 'c') {
          $change_cell->manakai_append_text ('Created');
        } elsif ($entry->[1] eq 'a') {
          $change_cell->manakai_append_text ('Associated with ');
          my $a_el = $doc->create_element ('a');
          $a_el->set_attribute
              (href => $app->page_url ($entry->[2], param => 'history'));
          $a_el->text_content ($entry->[2]);
          $change_cell->append_child ($a_el);
        } elsif ($entry->[1] eq 'r') {
          $change_cell->manakai_append_text ('Disassociated from ');
          my $a_el = $doc->create_element ('a');
          $a_el->set_attribute
              (href => $app->page_url ($entry->[2], param => 'history'));
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
      my $p_el = $doc->create_element ('p');
      $p_el->text_content ('No history data.');
      $table_el->parent_node->replace_child ($p_el, $table_el);
      $app->http->set_status (404);
    }

    set_foot_content ($app, $doc);

    $app->http->send_response_body_as_text ($doc->inner_html);
    $app->http->close_response_body;
    return $app->throw;
  } elsif ($param eq 'search' and not defined $app->path_dollar) {
    my $names = [];
    for_unique_words {
      push @$names, $_[0];
    } $name;

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

      my $searched = $db->es->search ($name);

      $app->http->add_response_header
          ('Content-Type' => 'text/plain; charset=utf-8');
      
      my $id_found = {};
      for my $item (@$searched) {
        my $id_prop = $db->id_prop->get_data ($item->{id});
        my $name = [keys %{$id_prop->{name}}]->[0] // '';
        my $title = $item->{title} // $name;
        $app->http->send_response_body_as_text
            (join '', $item->{score}, "\t", $item->{id}, "\t", $name, "\t", $title, "\x0A");
        $id_found->{$item->{id}}++;
      }

      # XXX old
      for my $id (sort {$index->{$b} <=> $index->{$a}} grep { not $id_found->{$_} } keys %$index) {
        my $id_prop = $db->id_prop->get_data ($id);
        my $name = [keys %{$id_prop->{name}}]->[0] // $id;
        $app->http->send_response_body_as_text
            (join '', $index->{$id}, "\t", $id, "\t", $name, "\t", $name, "\x0A");
      }

      $app->http->close_response_body;
      return $app->throw;
    } elsif ($param eq 'posturl' or $param eq 'postpara') {
      my ($id, undef) = prepare_by_name ($db, $name, $app->path_dollar);

      if (defined $app->path_dollar and not defined $id) {
        return $app->throw_error (404);
      }

      $app->requires_request_method ({POST => 1});
      $app->requires_editable;
      my $user = '(anon)'; #$cgi->remote_user // '(anon)';
      my $added_text;
      if ($param eq 'posturl') {
        $added_text = '<' . ($app->text_param ('url') // '') . '>';

        my $credit = $app->text_param ('credit') // '';
        $added_text = '(' . $credit . ")\n" . $added_text if length $credit;

        my $timestamp = $app->text_param ('timestamp') // '';
        if (length $timestamp) {
          $added_text = '(Referenced: [TIME[' . $timestamp . "]])\n". $added_text;
        }

        my $title = $app->text_param ('title') // '';
        if (length $title) {
          $title =~ s/(\[|\])/'''$1'''/g;
          my $tl = $app->text_param ('title-lang') // '';
          if (length $tl) {
            $title = '[CITE@' . $tl . '[' . $title . ']]';
          } else {
            $title = '[CITE[' . $title . ']]';
          }
          $added_text = $title . "\n" . $added_text;
        }

        my $quote = $app->text_param ('quote') // '';
        if (length $quote) {
          $quote =~ s/[\x0D\x0A]+/\n> /g;
          $added_text = qq{[FIG(quote)[\n[FIGCAPTION[\n[%%] $added_text\n]FIGCAPTION]\n\n> $quote\n\n]FIG]\n};
        } else {
          $added_text = "[%%] $added_text";
        }
      } elsif ($param eq 'postpara') {
        $added_text = $app->text_param ('text') // '';
      } else {
        die "Bad param |$param|";
      }
      normalize_content (\$added_text);

      my $next_id = 1;
      APPEND: { if (defined $id) { ## Existing document
        ## This must be done before the ID lock.
        $db->name_inverted_index->lock;

        my $id_lock = $db->id_lock->get_lock ($id);
        $id_lock->lock;
        
        my $id_prop = $db->id_prop->get_data ($id);
        last APPEND unless $id_prop;
        last APPEND if $id_prop->{'content-type'} ne 'text/x-suikawiki';
        
        my $textref = $db->id_content->get_data ($id);
        my $has_id = {};
        while ($$textref =~ /\[([0-9]+)\]/g) {
          $has_id->{0+$1} = 1;
        }
        $next_id++ while $has_id->{$next_id};
        $added_text =~ s/\[%%\]/[$next_id]/;
        $$textref .= "\n\n" . $added_text;
        
        $id_prop->{modified} = time;
        $id_prop->{hash} = string_hash $$textref;
        
        my $vc = $db->vc;
        local $db->id_content->{version_control} = $vc;
        local $db->id_prop->{version_control} = $vc;
        
        $db->id_content->set_data ($id => $textref);
        $db->id_prop->set_data ($id => $id_prop);
        
        $vc->commit_changes ("updated by $user");

        ## TODO: non-default content-type support
        my $cache_prop = $db->id_cache_prop->get_data ($id);
        my $doc = $id_prop ? get_xml_data ($db, $id, $id_prop, $cache_prop) : undef;
        if (defined $doc) {
          #require SWE::Object::Document;
          #my $document = SWE::Object::Document->new (db => $db, id => $id);
          #$document->{name_prop_db} = $db->name_prop;
          #$document->update_tfidf ($doc);
          $db->es->update ($id, $id_prop->{title}, $doc);

          my $url = $app->name_url ($name, $id);
          $db->feed->post
              ($app->http->url->resolve_string ($url)->stringify, $name);
        }

        return $app->throw_manual_redirect
            ($app->name_url ($name, $id, anchor => $next_id),
             status => 303, reason_phrase => 'Appended');
      }} # APPEND

      { ## New document
        my $new_names = {$name => 1};
        $added_text =~ s/\[%%\]/[$next_id]/;

        $db->names_lock->lock;
        my $time = time;
        
        require SWE::Object::Document;
        my $document = SWE::Object::Document->new_id (db => $db);
        $document->{name_prop_db} = $db->name_prop;
        
        my $id = $document->id;
        
        {
          ## This must be done before the ID lock.
          $db->name_inverted_index->lock;
          
          my $id_lock = $db->id_lock->get_lock ($id);
          $id_lock->lock;
          
          my $vc = $db->vc;
          local $db->id_content->{version_control} = $vc;
          local $db->id_prop->{version_control} = $vc;
          $vc->add_file ($db->id->{file_name});
          
          my $id_history_db = $db->id_history;
          local $id_history_db->{version_control} = $vc;
          
          $db->id_content->set_data ($id => \$added_text);
          
          my $id_props = {};
          
          $id_history_db->append_data ($id => [$time, 'c']);
          $id_props->{modified} = $time;
          
          for (keys %$new_names) {
            $id_props->{name}->{$_} = 1;
            $id_history_db->append_data ($id => [$time, 'a', $_]);
          }
          
          $id_props->{'content-type'} = 'text/x-suikawiki';
          $id_props->{hash} = string_hash $added_text;
          $db->id_prop->set_data ($id => $id_props);
          
          $vc->commit_changes ("created by $user");
          
          ## TODO: non-default content-type support
          my $cache_prop = $db->id_cache_prop->get_data ($id);
          my $doc = $id_props ? get_xml_data ($db, $id, $id_props, $cache_prop) : undef;
          
          if (defined $doc) {
            #$document->update_tfidf ($doc);
            $db->es->update ($id, $id_props->{title}, $doc);
          }
          
          $id_lock->unlock;
        }

        $document->associate_names ($new_names, user => $user, time => $time);

        return $app->throw_manual_redirect
            ($app->name_url ($name, $id, anchor => $next_id),
             status => 303, reason_phrase => 'Appended');
      }
    } else {
      $name .= '$' . $app->path_dollar if defined $app->path_dollar;
      $name .= ';' . $param;
      return $app->throw_redirect
          ($app->name_url ($name),
           status => 301, reason_phrase => 'Not found');
    }
  } elsif ($path[0] eq 'i' and @path == 2 and not defined $app->path_dollar) {
    my $param = $app->path_param;
    unless (defined $param) {
      if ($app->http->request_method eq 'POST') {
        $app->requires_editable;
        my $id = $path[1] + 0;
        
        ## This must be done before the ID lock.
        $db->name_inverted_index->lock;

        my $id_lock = $db->id_lock->get_lock ($id);
        $id_lock->lock;
        
        my $id_prop = $db->id_prop->get_data ($id)
            or $app->throw_error (404);
        my $ct = get_content_type_parameter ($app) or return; # thrown

        my $prev_hash = $app->bare_param ('hash') // '';
        my $current_hash = $id_prop->{hash} //
            string_hash ${$db->id_content->get_data ($id) // \''};
        unless ($prev_hash eq $current_hash) {
          ## TODO: conflict message
          return $app->throw_error (409);
        }

        my $textref = \ ($app->text_param ('text') // '');
        normalize_content ($textref);

        $id_prop->{'content-type'} = $ct;
        $id_prop->{modified} = time;
        $id_prop->{hash} = string_hash $$textref;

        my $title = $app->text_param ('title');
        if (defined $title) {
          normalize_content (\$title);
          $id_prop->{title} = $title;
          $id_prop->{'title-type'} = 'text/plain'; ## TODO: get_parameter
        }

        my $historical = $app->text_param ('historical');
        if ($historical) {
          $id_prop->{historical} = 1;
        } else {
          delete $id_prop->{historical};
        }

        my $legal = $app->text_param ('legal');
        if ($legal) {
          $id_prop->{legal} = 1;
        } else {
          delete $id_prop->{legal};
        }

        my $sensitive = $app->text_param ('sensitive');
        if ($sensitive) {
          $id_prop->{sensitive} = 1;
        } else {
          delete $id_prop->{sensitive};
        }

        my $parent = $app->text_param ('parent');
        if (defined $parent and length $parent) {
          $id_prop->{parent} = $parent;
        } else {
          delete $id_prop->{parent};
        }

        my $vc = $db->vc;
        local $db->id_content->{version_control} = $vc;
        local $db->id_prop->{version_control} = $vc;
        
        $db->id_content->set_data ($id => $textref);
        $db->id_prop->set_data ($id => $id_prop);
        
        my $user = '(anon)'; #$cgi->remote_user // '(anon)';
        $vc->commit_changes ("updated by $user");

        ## TODO: non-default content-type support
        my $cache_prop = $db->id_cache_prop->get_data ($id);
        my $doc = $id_prop ? get_xml_data ($db, $id, $id_prop, $cache_prop) : undef;

        my $url_title = [keys %{$id_prop->{name} or {}}]->[0];
        my $url = $app->name_url ($url_title, $id);
        $app->http->add_response_header ('X-SW-Hash' => $id_prop->{hash});
        if ($app->bare_param ('no-redirect')) {
          $app->send_redirect ($url, status => 201, reason_phrase => 'Saved');
        } else {
          $app->send_redirect ($url, status => 303, reason_phrase => 'Saved');
        }

        if (defined $doc) {
          #require SWE::Object::Document;
          #my $document = SWE::Object::Document->new (db => $db, id => $id);
          #$document->{name_prop_db} = $db->name_prop;
          #$document->update_tfidf ($doc);
          $db->es->update ($id, $title, $doc);

          $db->feed->post
              ($app->http->url->resolve_string ($url)->stringify,
               defined $title && length $title ? $title : $url_title);
        }

        return $app->throw;
      } else { # GET
        my $id = $path[1] + 0;
        my $id_prop = $db->id_prop->get_data ($id)
            or $app->throw_error (404);
        my $url = $app->name_url ([keys %{$id_prop->{name} or {}}]->[0], $id);
        $app->http->add_response_header ('X-SW-Hash' => $id_prop->{hash});
        $app->send_redirect ($url, status => 302);
        return $app->throw;
      }

    } elsif ($param eq 'edit') {
      my $id = $path[1] + 0;
      
      my $textref = $db->id_content->get_data ($id);
      if (defined $textref) {
        $app->http->add_response_header
            ('Content-Type' => 'text/html; charset=utf-8');
        $app->http->add_response_header
            ('Cache-Control' => 'no-cache');

      require SWE::Object::Document;
      my $doc = SWE::Object::Document->new (db => $db, id => $id);

      my $id_prop = $db->id_prop->get_data ($id);
      my $names = $id_prop->{name} || {};
      my $hash = $id_prop->{hash} // string_hash $$textref;

      ## TODO: <select name=title-type>
      my $html_doc = new Web::DOM::Document;
      $html_doc->manakai_is_html (1);
      $html_doc->inner_html (q[<!DOCTYPE HTML><title>Edit</title>
<body onbeforeunload="return 'Really?'">
<h1>Edit</h1>
<div class="nav swe-names"></div>

<div class=section>
<h2>Page</h2>

<form method=post accept-charset=utf-8 onsubmit="document.body.onbeforeunload = null">
<p><button type=submit>Update</button>
<p><label><strong>Page title</strong>:<br>
<input name=title></label>
<p><label for=page-body-text><strong>Page body</strong></label>:
<div class=body-area>
<span class=text-toolbar></span>
<textarea name=text id=page-body-text autofocus></textarea>
</div>
<p><button type=submit>Update</button>
<input type=hidden name=hash>
<select name=content-type></select>
<label><input type=checkbox name=historical> Historical</label>
<label><input type=checkbox name=legal> Legal</label>
<label><input type=checkbox name=sensitive> Sensitive</label>
<label>Parent: <input name=parent></label>
[<a rel=help>Help</a> / <a rel=license>License</a>]
</form>

</div>

<div class="section page-names">
<h2>Page name(s)</h2>

<form method=post accept-charset=utf-8>
<p><textarea name=names></textarea>
<p><button type=submit>Save</button>
</form>
</div>
]);
      set_head_content ($app, \@path, $html_doc, $id, [],
                        [{name => 'ROBOTS', content => 'NOINDEX'}]);
      my $form_el = $html_doc->get_elements_by_tag_name ('form')->[0];
      $form_el->set_attribute (action => $id);
      my $ta_el = $form_el->get_elements_by_tag_name ('textarea')->[0];
      $ta_el->text_content ($$textref);

      my $title_field = $form_el->get_elements_by_tag_name ('input')->[0];
      $title_field->set_attribute (value => $id_prop->{title} // '');

      my $hash_field = $form_el->get_elements_by_tag_name ('input')->[1];
      $hash_field->set_attribute (value => $hash);

      my $historical_field = $form_el->get_elements_by_tag_name ('input')->[2];
      $historical_field->set_attribute (checked => '') if $id_prop->{historical};

      my $legal_field = $form_el->get_elements_by_tag_name ('input')->[3];
      $legal_field->set_attribute (checked => '') if $id_prop->{legal};

      my $sensitive_field = $form_el->get_elements_by_tag_name ('input')->[4];
      $sensitive_field->set_attribute (checked => '') if $id_prop->{sensitive};

      my $parent_field = $form_el->get_elements_by_tag_name ('input')->[5];
      $parent_field->set_attribute (value => $id_prop->{parent})
          if defined $id_prop->{parent};

      my $ct = $id_prop->{'content-type'} // 'text/x-suikawiki';
      set_content_type_options
          ($html_doc,
           $form_el->get_elements_by_tag_name ('select')->[0] => $ct);

      my $a_el = $form_el->get_elements_by_tag_name ('a')->[0];
      $a_el->set_attribute (href => $app->help_page_url);

      $a_el = $form_el->get_elements_by_tag_name ('a')->[1];
      $a_el->set_attribute (href => $app->license_page_url);

      $form_el = $html_doc->get_elements_by_tag_name ('form')->[1];
      $form_el->set_attribute (action => $id . ';names');
      
      $ta_el = $form_el->get_elements_by_tag_name ('textarea')->[0];
      $ta_el->text_content (join "\x0A", keys %$names);

      my $nav_el = $html_doc->get_elements_by_tag_name ('div')->[0];
      for (keys %$names) {
        my $a_el = $html_doc->create_element ('a');
        $a_el->set_attribute (href => $app->name_url ($_, $id));
        $a_el->text_content ($_);
        $nav_el->append_child ($a_el);
        $nav_el->manakai_append_text (' ');
      }

        set_foot_content ($app, $html_doc);
        $app->http->send_response_body_as_text ($html_doc->inner_html);
        $app->http->close_response_body;
        return $app->throw;
      }
    } elsif ($param eq 'names') {
      $app->requires_request_method ({POST => 1});
      $app->requires_editable;
      my $id = $path[1] + 0;

      my $vc = $db->vc;
      local $db->name_prop->{version_control} = $vc;
      local $db->id_prop->{version_control} = $vc;
      
      my $id_history_db = $db->id_history;
      local $id_history_db->{version_control} = $vc;

      my $names_history_db = $db->name_history;
      local $names_history_db->{version_control} = $vc;

      my $time = time;

      $db->names_lock->lock;
      
      my $id_prop = $db->id_prop->get_data ($id);
      my $old_names = $id_prop->{name} || {};
      
      my $new_names = {};
      for (split /\x0D\x0A?|\x0A/, $app->text_param ('names')) {
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
        my $new_name_prop = $db->name_prop->get_data ($new_name);
        unless (defined $new_name_prop) {
          $names_history_db->append_data ($new_name => [$time, 'c']);
        }
        $new_name_prop->{name} = $new_name;
        push @{$new_name_prop->{id} ||= []}, $id;
        $db->name_prop->set_data ($new_name => $new_name_prop);

        $id_history_db->append_data ($id => [$time, 'a', $new_name]);
        $names_history_db->append_data ($new_name => [$time, 'a', $id]);
      }

      for my $removed_name (keys %$removed_names) {
        my $removed_name_prop = $db->name_prop->get_data ($removed_name);
        for (0..$#{$removed_name_prop->{id} or []}) {
          if ($removed_name_prop->{id}->[$_] eq $id) {
            splice @{$removed_name_prop->{id}}, $_, 1, ();
            last;
          }
        }
        $db->name_prop->set_data ($removed_name => $removed_name_prop);

        $id_history_db->append_data ($id => [$time, 'r', $removed_name]);
        $names_history_db->append_data ($removed_name => [$time, 'r', $id]);
      }

      $id_prop->{name} = $new_names;
      $db->id_prop->set_data ($id => $id_prop);

      my $user = '(anon)'; #$cgi->remote_user // '(anon)';
      $vc->commit_changes ("id-name association changed by $user");

      $db->names_lock->unlock;

      $app->http->set_status (204, 'Changed');
      $app->http->close_response_body;
      return $app->throw;
    } elsif ($param eq 'history' and not defined $app->path_dollar) {
      my $id = $path[1] + 0;

      my $id_history_db = $db->id_history;
      my $history = $id_history_db->get_data ($id);

      $app->http->add_response_header
          ('Content-Type' => 'text/html; charset=utf-8');

      my $doc = new Web::DOM::Document;
      $doc->manakai_is_html (1);
      $doc->inner_html (q[<!DOCTYPE HTML><html lang=en><title></title><h1></h1>
<div class=section><h2>History</h2><table>

<thead>
<tr><th scope=col>Time<th scope=col>Change

<tbody>
                        
</table></div>]);
      set_head_content ($app, \@path, $doc, undef, [], []);

    my $title_el = $doc->get_elements_by_tag_name ('title')->[0];
    $title_el->inner_html ('History &mdash; #');
    $title_el->manakai_append_text ($id);
    
    my $h1_el = $doc->get_elements_by_tag_name ('h1')->[0];
    $h1_el->text_content ('#' . $id);
    
    my $table_el = $doc->get_elements_by_tag_name ('table')->[0];
    if ($history) {
      my $tbody_el = $table_el->last_child;

      for my $entry (@$history) {
        my $tr_el = $doc->create_element ('tr');
        
        my $date_cell = $doc->create_element ('td');
        my @time = gmtime ($entry->[0] || 0);
        $date_cell->inner_html ('<time>' . (sprintf '%04d-%02d-%02d %02d:%02d:%02d+00:00',
               $time[5] + 1900, $time[4] + 1, $time[3],
               $time[2], $time[1], $time[0]) . '</time>');
        $tr_el->append_child ($date_cell);

        my $change_cell = $doc->create_element ('td');
        if ($entry->[1] eq 'c') {
          $change_cell->manakai_append_text ('Created');
        } elsif ($entry->[1] eq 'a') {
          $change_cell->manakai_append_text ('Associated with ');
          my $a_el = $doc->create_element ('a');
          $a_el->set_attribute
              (href => $app->name_url ($entry->[2], undef, param => 'history'));
          $a_el->text_content ($entry->[2]);
          $change_cell->append_child ($a_el);
        } elsif ($entry->[1] eq 'r') {
          $change_cell->manakai_append_text ('Disassociated from ');
          my $a_el = $doc->create_element ('a');
          $a_el->set_attribute
              (href => $app->name_url ($entry->[2], undef, param => 'history'));
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
      my $p_el = $doc->create_element ('p');
      $p_el->text_content ('No history data.');
      $table_el->parent_node->replace_child ($p_el, $table_el);
    }

      set_foot_content ($app, $doc);
      $app->http->send_response_body_as_text ($doc->inner_html);
      $app->http->close_response_body;
      return $app->throw;

    } elsif (($param eq 'datahistory' or $param eq 'datahistory.json') and
             not defined $app->path_dollar) {
      # /i/{id};datahistory
      # /i/{id};datahistory.json
      my $id = $path[1] + 0;
      my $result = $db->id_data_history->get_data ($id);
      {
        if ($result->{data}) {
          $app->http->set_response_last_modified ($result->{last_modified});
          if ($param eq 'datahistory') {
            my $doc = new Web::DOM::Document;
            $doc->manakai_is_html (1);
            $doc->inner_html (q[<!DOCTYPE HTML><html lang=en><title></title><h1></h1>
<div class=section><h2>History</h2><table>

<thead>
<tr><th scope=col>Revision<th scope=col>Time<th scope=col>Change

<tbody></table></div>]);
            $doc->title ('History of article #' . $id);
            my $h1_el = $doc->get_elements_by_tag_name ('h1')->[0];
            $h1_el->text_content ('#' . $id);
            my $links = [];
            push @$links,
                {rel => 'alternate',
                 type => 'application/json',
                 href => $app->page_url ($id, param => 'datahistory.json')};
            set_head_content ($app, \@path, $doc, undef, $links, []);
            my $tbody = $doc->get_elements_by_tag_name ('table')->[0]->tbodies->[0];
            for my $rev (@{$result->{data}->{revs}}) {
              my $tr = $doc->create_element ('tr');
              {
                my $cell = $doc->create_element ('th');
                my $a = $doc->create_element ('a');
                $a->href ($app->id_rev_url ($id, $rev->{rev}, $result->{data}->{sw3_name}));
                $a->text_content ($rev->{rev});
                $cell->append_child ($a);
                $tr->append_child ($cell);
              }
              {
                my $cell = $doc->create_element ('td');
                my $time = $doc->create_element ('time');
                my @time = gmtime $rev->{time};
                $time->text_content
                    (sprintf '%04d-%02d-%02d %02d:%02d:%02d+00:00',
                     $time[5] + 1900, $time[4] + 1, $time[3],
                     $time[2], $time[1], $time[0]);
                $cell->append_child ($time);
                $tr->append_child ($cell);
              }
              {
                my $cell = $doc->create_element ('td');
                if ($rev->{event} eq 'misc') {
                  $cell->text_content ($rev->{comment});
                } else {
                  $cell->text_content ({
                    created => 'Created',
                    updated => 'Updated',
                    'from-sw3' => 'Converted from SuikaWiki3 database',
                    'id-name' => 'ID/Name association updated',
                  }->{$rev->{event}} // $rev->{event});
                }
                $tr->append_child ($cell);
              }
              $tbody->append_child ($tr);
            } # $rev
            set_foot_content ($app, $doc);
            $app->http->add_response_header ('Content-Type' => 'text/html; charset=utf-8');
            $app->http->send_response_body_as_text ($doc->inner_html);
            $app->http->close_response_body;
          } else {
            $app->send_json ($result->{data});
          }
        } else {
          $app->send_error (404);
        }
      }
      return $app->throw;
    }
  } elsif ($path[0] eq 'new-page' and @path == 1) {
    if ($app->http->request_method eq 'POST') {
      $app->requires_editable;
      my $new_names = {};
      for (split /\x0D\x0A?|\x0A/, $app->text_param ('names')) {
        $new_names->{normalize_name ($_)} = 1;
      }
      delete $new_names->{''};
      $new_names->{'(no title)'} = 1 unless keys %$new_names;

      my $user = '(anon)'; #$cgi->remote_user // '(anon)';
      my $ct = get_content_type_parameter ($app) or return;

      my $content = $app->text_param ('text') // '';
      normalize_content (\$content);

      $db->names_lock->lock;
      my $time = time;

    require SWE::Object::Document;
    my $document = SWE::Object::Document->new_id (db => $db);
    $document->{name_prop_db} = $db->name_prop;

    my $id = $document->id;
    my $id_prop = {};

    {
      ## This must be done before the ID lock.
      $db->name_inverted_index->lock;

      my $id_lock = $db->id_lock->get_lock ($id);
      $id_lock->lock;

      my $vc = $db->vc;
      local $db->id_content->{version_control} = $vc;
      local $db->id_prop->{version_control} = $vc;
      $vc->add_file ($db->id->{file_name});
      
      my $id_history_db = $db->id_history;
      local $id_history_db->{version_control} = $vc;

      $db->id_content->set_data ($id => \$content);

      $id_history_db->append_data ($id => [$time, 'c']);
      $id_prop->{modified} = $time;
      
      for (keys %$new_names) {
        $id_prop->{name}->{$_} = 1;
        $id_history_db->append_data ($id => [$time, 'a', $_]);
      }

      $id_prop->{'content-type'} = $ct;
      $id_prop->{hash} = string_hash $content;
      $id_prop->{title} = $app->text_param ('title') // '';
      normalize_content (\($id_prop->{title}));
      $id_prop->{'title-type'} = 'text/plain'; ## TODO: get_parameter
      $db->id_prop->set_data ($id => $id_prop);

      $vc->commit_changes ("created by $user");

      ## TODO: non-default content-type support
      my $cache_prop = $db->id_cache_prop->get_data ($id);
      my $doc = $id_prop ? get_xml_data ($db, $id, $id_prop, $cache_prop) : undef;
      
      if (defined $doc) {
        #$document->update_tfidf ($doc);
        $db->es->update ($id, $id_prop->{title}, $doc);
      }
      
      $id_lock->unlock;
    }

    $document->associate_names ($new_names, user => $user, time => $time);

      $app->http->add_response_header ('X-SW-Hash' => $id_prop->{hash});
      
      my $post_url = $app->http->url->resolve_string ("i/$id");
      $app->http->add_response_header ('X-SW-Post-URL' => $post_url->stringify);

      my $url = $app->name_url ([keys %$new_names]->[0], $id);
      if ($app->bare_param ('no-redirect')) {
        return $app->throw_redirect
            ($url, status => 201, reason_phrase => 'Created');
      } else {
        return $app->throw_redirect
            ($url, status => 303, reason_phrase => 'Created');
      }
    } else { # GET
      $app->http->add_response_header
          ('Content-Type' => 'text/html; charset=utf-8');

    ## TODO: select name=title-type
    my $doc = new Web::DOM::Document;
    $doc->manakai_is_html (1);
    $doc->inner_html (q[<!DOCTYPE HTML><title>New page</title>
<body onbeforeunload="return 'Really?'">
<h1>New page</h1>
<form action=new-page method=post accept-charset=utf-8 onsubmit="document.body.onbeforeunload=null">
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
    set_head_content ($app, \@path, $doc, undef, [],
                      [{name => 'ROBOTS', content => 'NOINDEX'}]);

    my $form_el = $doc->get_elements_by_tag_name ('form')->[0];
    set_content_type_options
        ($doc, $form_el->get_elements_by_tag_name ('select')->[0]);

    my $names = $app->text_param ('names') // '';
    $form_el->get_elements_by_tag_name ('textarea')->[0]
        ->text_content ($names);

      my $a_el = $form_el->get_elements_by_tag_name ('a')->[0];
      $a_el->set_attribute (href => $app->help_page_url);

      $a_el = $form_el->get_elements_by_tag_name ('a')->[1];
      $a_el->set_attribute (href => $app->license_page_url);
      set_foot_content ($app, $doc);

      $app->http->send_response_body_as_text ($doc->inner_html);
      $app->http->close_response_body;
      return $app->throw;
    }
  }

  return $app->throw_error (404);
} # main

sub prepare_by_name ($$$) {
  my ($db, $name, $id_cand) = @_;
  my $name_prop = $db->name_prop->get_data ($name);
  my $ids = $name_prop->{id} || [];

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

sub get_content_type_parameter ($) {
  my $app = $_[0];
  my $ct = $app->bare_param ('content-type') // 'text/x-suikawiki';
  
  my $valid_ct;
  for (@ContentMediaType) {
    if ($_->{type} eq $ct) {
      $valid_ct = 1;
      last;
    }
  }
  unless ($valid_ct) {
    return $app->throw_error
        (400, reason_phrase => 'content-type parameter not allowed');
    ## XXX 406?
  }

  return $ct;
} # get_content_type_parameter

sub set_content_type_options ($$;$) {
  my ($doc, $select_el, $ct) = @_;
  $ct //= 'text/x-suikawiki';
  
  my $has_ct;
  for (@ContentMediaType) {
    next unless defined $_->{label};
    my $option_el = $doc->create_element ('option');
    $option_el->set_attribute (value => $_->{type});
    $option_el->text_content ($_->{label});
    if ($_->{type} eq $ct) {
      $option_el->set_attribute (selected => '');
      $has_ct = 1;
    }
    $select_el->append_child ($option_el);
  }
  unless ($has_ct) {
    my $option_el = $doc->create_element ('option');
    $option_el->set_attribute (value => $ct);
    $option_el->text_content ($ct);
    $option_el->set_attribute (selected => '');
    $select_el->append_child ($option_el);
  }
} # set_content_type_options

sub get_xml_data ($$$$) {
  my ($db, $id, $id_prop, $cache_prop) = @_;

  my $cached_hash = $cache_prop->{'cached-hash'};

  if ($cached_hash) {
    my $content_hash = $id_prop->{hash} || '';
    
    if ($cached_hash ne $content_hash) {
      undef $cached_hash;
    }
  }

  my $content_cache_db = $db->id_dom_cache;
  my $doc;
  if ($cached_hash) {
    $doc = $content_cache_db->get_data ($id);
  } else {
    my $textref = $db->id_content->get_data ($id);
    if ($textref) {
      my $p = SWML::Parser->new;
      
      $doc = new Web::DOM::Document;
      $p->parse_char_string ($$textref => $doc);
      
      $content_cache_db->set_data ($id => $doc);

      $cache_prop->{'cached-hash'} = string_hash $$textref;
      $db->id_cache_prop->set_data ($id => $cache_prop);
    } else {
      ## Content not found.
      $doc = new Web::DOM::Document;
    }
  }

  return $doc;
} # get_xml_data

sub set_head_content ($$$;$$$) {
  my ($app, $path, $doc, $id, $links, $metas) = @_;
  my $head_el = $doc->manakai_head;

  push @{$links ||= []},
      {rel => 'stylesheet', href => $app->css_url},
      {rel => 'license', href => $app->license_page_url};
  
  for my $item (@$links) {
    my $link_el = $doc->create_element ('link');
    for (keys %$item) {
      $link_el->set_attribute ($_ => $item->{$_});
    }
    $head_el->append_child ($link_el);
  }

  for my $item (@{$metas or []}) {
    my $meta_el = $doc->create_element ('meta');
    $meta_el->set_attribute (name => $item->{name} // '');
    $meta_el->set_attribute (content => $item->{content} // '');
    $head_el->append_child ($meta_el);
  }

  my $script_el = $doc->create_element ('script');
  $script_el->set_attribute (src => "https://fonts.suikawiki.org/swcf/composite.js");
  $script_el->set_attribute ('data-install', '');
  $script_el->set_attribute ('async', '');
  $head_el->append_child ($script_el);
} # set_head_content

sub set_foot_content ($$) {
  my ($app, $doc) = @_;
  my $body_el = $doc->last_child->last_child;
  my $script_el = $doc->create_element ('script');
  $script_el->set_attribute (src => $app->js_url);
  $body_el->append_child ($script_el);
} # set_foot_content

1;

=head1 LICENSE

Copyright 2002-2023 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
