package SWE::Warabe::App;
use strict;
use warnings;
use Digest::SHA;
use Warabe::App;
use Warabe::App::Role::JSON;
push our @ISA, qw(Warabe::App Warabe::App::Role::JSON);
use Wanage::URL qw(percent_encode_c percent_decode_c);

sub config ($;$) {
  if (@_ > 1) {
    $_[0]->{config} = $_[1];
  }
  return $_[0]->{config};
} # config

sub db_root_path ($;$) {
  if (@_ > 1) {
    $_[0]->{db_root_path} = $_[1];
  }
  return $_[0]->{db_root_path};
} # db_root_path

sub db ($) {
  require SWE::DB;
  return $_[0]->{db} ||= SWE::DB->new_from_root_path ($_[0]->db_root_path);
} # db

sub path_segments ($) {
  return $_[0]->{path_segments};
} # path_segments

sub path_param ($) {
  return $_[0]->{path_param};
} # path_param

sub path_dollar ($) {
  return $_[0]->{path_dollar};
} # path_dollar

sub parse_path ($) {
  my $self = $_[0];
  my $path = $self->http->url->{path};
  if ($path =~ s[;([^/]*)\z][]) {
    $self->{path_param} = percent_decode_c ($1);
  }
  if ($path =~ s[\$([^/]*)\z][]) {
    $self->{path_dollar} = percent_decode_c ($1);
  }

  my @path = map { percent_decode_c ($_) } split m#/#, $path, -1;
  shift @path while @path and $path[0] eq '';
  $self->{path_segments} = \@path;
} # parse_path

sub requires_editable ($) {
  my $app = $_[0];
  my $allowed = $app->config->get_file_json ('edit_basic_auth');
  my $http = $app->http;
  my $auth = $http->request_auth;
  if ($auth->{auth_scheme} and $auth->{auth_scheme} eq 'basic') {
    if (defined $allowed->{$auth->{userid}} and
        defined $auth->{password}) {
      my $pwd = Digest::SHA::sha512_hex ($auth->{password});
      if ($pwd eq $allowed->{$auth->{userid}}) {
        return;
      }
    }
  }

  $http->set_status (401);
  $http->set_response_auth ('basic', realm => 'Edit');
  $http->set_response_header
      ('Content-Type' => 'text/plain; charset=us-ascii');
  $http->send_response_body_as_ref (\'401 Authorization required');
  $http->close_response_body;
  $app->throw;
} # requires_editable

sub name_url ($$;$%) {
  my (undef, $name, $id, %args) = @_;
  my $url = q</n/> . percent_encode_c $name;
  $url .= ';' . percent_encode_c $args{param} if defined $args{param};
  $url .= '$' . (0+$id) if defined $id;
  $url .= '?format=' . percent_encode_c $args{format} if defined $args{format};
  $url .= '#anchor-' . percent_encode_c $args{anchor} if defined $args{anchor};
  return $url;
} # name_url

sub home_page_url ($) {
  my $self = $_[0];
  return $self->name_url ($self->config->get_text ('wiki_page_home'));
} # home_page_url

sub license_page_url ($) {
  my $self = $_[0];
  return $self->name_url ($self->config->get_text ('wiki_page_license'));
} # license_page_url

sub help_page_url ($) {
  my $self = $_[0];
  return $self->name_url ($self->config->get_text ('wiki_page_help'));
} # help_page_url

sub id_rev_url ($$$;$) {
  my ($self, $id, $rev, $sw3_name) = @_;
  if ($rev =~ /^6:(.+)$/) {
    return $1; # XXX
  } elsif ($rev =~ /^4:(.+)$/) {
    return sprintf q<http://suika.suikawiki.org/gate/cvs/melon/pub/suikawiki/sw4data/ids/%d/%d.txt?revision=%s>,
        $id / 1000,
        $id % 1000,
        $1;
  } elsif ($rev =~ /^3:(.+)$/) {
    return sprintf q<http://suika.suikawiki.org/gate/cvs/melon/pub/suikawiki/wikidata/page/%s?revision=%s>,
        $sw3_name,
        $1;
  } else {
    return $rev; ## error
  }
} # rev_history_url

sub page_create_url ($$) {
  return '/new-page' unless defined $_[1];
  return '/new-page?names=' . percent_encode_c ($_[1]);
} # page_create_url

sub page_url ($$%) {
  my ($self, $id, %args) = @_;
  my $url = '/i/' . (0+$id);
  $url .= ';' . percent_encode_c $args{param} if defined $args{param};
  return $url;
} # page_url

sub css_url ($) {
  return '/styles/sw';
} # css_url

sub js_url ($) {
  return '/scripts/sw';
} # js_url

1;

=head1 LICENSE

Copyright 2002-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
