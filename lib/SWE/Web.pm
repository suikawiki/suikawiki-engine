package SWE::Web;
use strict;
use warnings;
use Path::Tiny;
use Wanage::HTTP;
use SWE::Warabe::App;
use Web::DOM::Document;
require 'suikawiki/main.pl';

sub psgi_app ($$) {
  my (undef, $config) = @_;
  die "|SW_DB_DIR| is not specified" unless defined $ENV{SW_DB_DIR};
  my $db_path = path $ENV{SW_DB_DIR};
  return sub {
    my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
    my $app = SWE::Warabe::App->new_from_http ($http);
    $app->config ($config);
    $app->db_root_path ($db_path);

    # XXX accesslog
    warn sprintf "Access: [%s] %s %s\n",
        scalar gmtime, $app->http->request_method, $app->http->url->stringify;

    return $http->send_response (onready => sub {
      $app->execute (sub {
        SWE::Web->process ($app);
      });
    });
  };
} # psgi_app

my $static_root_path = path (__FILE__)->parent->parent->parent;

sub process ($$) {
  my ($class, $app) = @_;
  $app->parse_path;
  my $path = $app->path_segments;

  $app->requires_valid_content_length;
  $app->requires_mime_type;
  $app->requires_request_method;
  $app->requires_same_origin_or_referer_origin
      unless $app->http->request_method_is_safe;

  if (@$path == 0) {
    # /
    return $app->throw_redirect ($app->home_page_url, status => 302);
  } elsif (@$path == 1) {
    if ($path->[0] eq 'n' or $path->[0] eq 'i') {
      # /n
      # /i
      return $app->throw_redirect ($app->home_page_url, status => 302);
    } elsif ($path->[0] eq 'favicon.ico') {
      # /favicon.ico
      my $file_path = $static_root_path->child ('favicon.ico');
      $app->http->add_response_header
          ('Content-Type' => 'image/vnd.microsoft.icon');
      $app->http->set_response_last_modified ($file_path->stat->mtime);
      $app->http->send_response_body_as_ref (\($file_path->slurp));
      $app->http->close_response_body;
      return $app->throw;
    } elsif ($path->[0] eq 'robots.txt') {
      # /robots.txt
      my $file_path = $static_root_path->child ('robots.txt');
      $app->http->add_response_header
          ('Content-Type' => 'text/plain; charset=utf-8');
      $app->http->set_response_last_modified ($file_path->stat->mtime);
      $app->http->send_response_body_as_ref (\($file_path->slurp));
      $app->http->close_response_body;
      return $app->throw;
    } elsif ($path->[0] eq 'posturl') {
      # /posturl
      return $class->get_posturl ($app);
    } elsif ($path->[0] eq 'sw5') {
      # /sw5
      my $url = $app->http->original_url->{query} // '';
      $url = $app->http->url->resolve_string ($url)->get_canon_url->stringify;
      $url =~ s{^[^:]+://[^/]+/~wakaba/wiki/sw}{};
      $url =~ s{\+}{%2F}g;
      return $app->throw_redirect ($url, status => 301);
    } elsif ($path->[0] eq 'google5e610a4166d18843.html') {
      # For Google
      $app->send_plain_text ('google-site-verification: google5e610a4166d18843.html');
      return $app->throw;
    }
  } elsif (@$path == 2) {
    if ($path->[0] eq 'i' and $path->[1] eq '') {
      # /i/
      return $app->throw_redirect ($app->home_page_url, status => 302);
    } elsif ($path->[0] eq 'styles' and $path->[1] =~ /\A[a-z-]+\z/ and
             not defined $app->path_param and not defined $app->path_dollar) {
      my $file_path = $static_root_path->child ('styles', $path->[1] . '.css');
      if ($file_path->is_file) {
        $app->http->add_response_header
            ('Content-Type' => 'text/css; charset=utf-8');
        $app->http->set_response_last_modified ($file_path->stat->mtime);
        $app->http->send_response_body_as_ref (\($file_path->slurp));
        $app->http->close_response_body;
        return $app->throw;
      }
    } elsif ($path->[0] eq 'scripts' and $path->[1] =~ /\A[a-z-]+\z/ and
             not defined $app->path_param and not defined $app->path_dollar) {
      my $file_path = $static_root_path->child ('scripts', $path->[1] . '.js');
      if ($file_path->is_file) {
        $app->http->add_response_header
            ('Content-Type' => 'text/javascript; charset=utf-8');
        $app->http->set_response_last_modified ($file_path->stat->mtime);
        $app->http->send_response_body_as_ref (\($file_path->slurp));
        $app->http->close_response_body;
        return $app->throw;
      }
    } elsif ($path->[0] eq 'images' and $path->[1] =~ /\A[a-z-]+\.(png)\z/ and
             not defined $app->path_param and not defined $app->path_dollar) {
      my $ext = $1;
      my $file_path = $static_root_path->child ('images', $path->[1]);
      if ($file_path->is_file) {
        $app->http->add_response_header
            ('Content-Type' => {png => 'image/png'}->{$ext});
        $app->http->set_response_last_modified ($file_path->stat->mtime);
        $app->http->send_response_body_as_ref (\($file_path->slurp));
        $app->http->close_response_body;
        return $app->throw;
      }
    }
  }

  return SuikaWiki5::Main->main ($app);
} # process


sub get_posturl ($$) {
  my ($class, $app) = @_;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->inner_html (q{
    <!DOCTYPE html>
    <html lang=en class=suikawiki-bookmarklet-post>
      <link rel=stylesheet href=/styles/sw>
      <h1>Post a URL</h1>
      <form method=post accept-charset=utf-8 onsubmit="
        if (this.pageName.value.length == 0) return false;
        this.action = '/n/' + encodeURIComponent (this.pageName.value) + ';posturl';
      ">
        <p><label>Page: <input name=pageName autofocus></label>
        <p><label>URL: (<button type=button onclick=" form.elements.url.value = form.elements.url.value.replace (/#.*$/, '') ">No fragment</button>)<input type=url name=url></label>
        <p><label for=suikawiki-bookmarklet-post-title>Title</label>: (<label>Language: <input name=title-lang></label>) <input name=title id=suikawiki-bookmarklet-post-title><p><label>Credit: <input name=credit></label>
        <p class=buttons><button type=submit class=ok name=submit-button>OK</button>
        <p><label>Quotation: <textarea name=quote></textarea></label>
      </form>
  });
  my $form = $doc->forms->[0];
  $form->query_selector ('input[name=url]')->set_attribute
      (value => $app->text_param ('url') // '');
  $form->query_selector ('input[name=title]')->set_attribute
      (value => $app->text_param ('title') // '');
  $form->query_selector ('input[name=title-lang]')->set_attribute
      (value => $app->text_param ('title-lang') // '');
  $form->query_selector ('input[name=credit]')->set_attribute
      (value => $app->text_param ('credit') // '');
  $form->query_selector ('textarea[name=quote]')->text_content
      ($app->text_param ('quote') // '');
  
  $app->http->add_response_header ('Content-Type' => 'text/html; charset=utf-8');
  $app->http->send_response_body_as_text ($doc->inner_html);
  $app->http->close_response_body;
  return $app->throw;
} # get_posturl

1;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
