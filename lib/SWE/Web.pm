package SWE::Web;
use strict;
use warnings;
use Path::Tiny;
use Wanage::HTTP;
use SWE::Warabe::App;
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
  my $path = $app->path_segments;

  if ($path->[0] eq 'styles' and
      defined $path->[1] and $path->[1] =~ /\A[a-z-]+\z/ and
      not defined $path->[2]) {
    my $file_path = $static_root_path->child ('styles', $path->[1] . '.css');
    if ($file_path->is_file) {
      $app->http->add_response_header
          ('Content-Type' => 'text/css; charset=utf-8');
      $app->http->set_response_last_modified ($file_path->stat->mtime);
      $app->http->send_response_body_as_ref (\($file_path->slurp));
      $app->http->close_response_body;
      return $app->throw;
    }
  } elsif ($path->[0] eq 'scripts' and
           defined $path->[1] and $path->[1] =~ /\A[a-z-]+\z/ and
           not defined $path->[2]) {
    my $file_path = $static_root_path->child ('scripts', $path->[1] . '.js');
    if ($file_path->is_file) {
      $app->http->add_response_header
          ('Content-Type' => 'text/javascript; charset=utf-8');
      $app->http->set_response_last_modified ($file_path->stat->mtime);
      $app->http->send_response_body_as_ref (\($file_path->slurp));
      $app->http->close_response_body;
      return $app->throw;
    }
  } else {
    # XXX auth
    # XXX CSRF

    SuikaWiki5::Main->main ($app);
  }

  return $app->throw_error (404);
} # process

1;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
