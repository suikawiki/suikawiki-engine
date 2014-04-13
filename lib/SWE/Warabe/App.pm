package SWE::Warabe::App;
use strict;
use warnings;
use Warabe::App;
push our @ISA, qw(Warabe::App);
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

  my @path = map { s/\+/%2F/g; percent_decode_c ($_) } split m#/#, $path, -1;
  shift @path while @path and $path[0] eq '';
  $self->{path_segments} = \@path;
} # parse_path

sub name_url ($$;$%) {
  my (undef, $name, $id, %args) = @_;
  my $url = q</n/> . percent_encode_c $name;
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

sub cvs_archive_url ($$) {
  my ($self, $id) = @_;
  return sprintf '%sids/%d/%d.txt',
      $self->config->get_text ('wiki_url_cvs'),
      $id / 1000,
      $id % 1000;
} # cvs_archive_url

sub css_url ($) {
  return '/styles/sw';
} # css_url

sub js_url ($) {
  return '/scripts/sw';
} # js_url

1;
