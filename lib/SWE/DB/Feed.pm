package SWE::DB::Feed;
use strict;
use warnings;
use AnyEvent;
use Web::UserAgent::Functions qw(http_post);

sub new_from_config ($$) {
  return bless {config => $_[1]}, $_[0];
} # new_from_config

sub url ($) {
  return $_[0]->{config}->get_file_text ('feed_url');
} # url

sub basic_auth ($) {
  return [$_[0]->{config}->get_file_base64_text ('feed_user'),
          $_[0]->{config}->get_file_base64_text ('feed_password')];
} # basic_auth

sub post ($$$) {
  my ($self, $url, $title) = @_;

  my $cv = AE::cv;
  http_post
      url => $self->url,
      basic_auth => $self->basic_auth,
      params => {
        title => $title,
        url => $url,
      },
      anyevent => 1,
      cb => sub { $cv->send };
  $cv->recv;
} # post

1;
