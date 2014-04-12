package SWE::Web;
use strict;
use warnings;
use Wanage::HTTP;
use Warabe::App;
require 'suikawiki/main.pl';

sub psgi_app ($$) {
  my (undef, $config) = @_;
  return sub {
    my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
    my $app = Warabe::App->new_from_http ($http);
    return $http->send_response (onready => sub {
      $app->execute (sub {
        SWE::Web->process ($app, $config);
      });
    });
  };
} # psgi_app

sub process ($$$) {
  my ($class, $app, $config) = @_;
  my $path = $app->path_segments;

  # XXX
  SuikaWiki5::Main->main;

  return $app->throw_error (404);
} # process

1;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
