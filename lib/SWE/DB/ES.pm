package SWE::DB::ES;
use strict;
use warnings;
use AnyEvent;
use Web::UserAgent::Functions qw(http_post_data);
use JSON::Functions::XS qw(perl2json_bytes json_bytes2perl);
use Char::Transliterate::Kana;

sub new_from_config ($$) {
  return bless {config => $_[1]}, $_[0];
} # new_from_config

sub url_prefix ($) {
  return $_[0]->{config}->get_file_text ('es_index_url');
} # url_prefix

sub basic_auth ($) {
  return [$_[0]->{config}->get_file_base64_text ('es_user'),
          $_[0]->{config}->get_file_base64_text ('es_password')];
} # basic_auth

sub update ($$$$) {
  my ($self, $id, $title, $doc) = @_;
  my $text = ($title // '') . "\n" . $doc->document_element->text_content;
  katakana_to_hiragana $text;
  undef $title unless defined $title and length $title;

  my $url_prefix = $self->url_prefix;
  my $cv = AE::cv;
  http_post_data
      override_method => 'PUT',
      url => qq<$url_prefix/i/$id>,
      basic_auth => $self->basic_auth,
      content => perl2json_bytes {
        title => $title,
        content => $text,
      },
      anyevent => 1,
      cb => sub { $cv->send };
  $cv->recv;
} # update

sub search ($$) {
  my ($self, $word) = @_;
  katakana_to_hiragana $word;

  my $url_prefix = $self->url_prefix;
  my $cv = AE::cv;
  http_post_data
      url => qq<$url_prefix/i/_search?fields=title>,
      basic_auth => $self->basic_auth,
      content => perl2json_bytes {
        query => {
          match => {content => {
            query => $word,
            operator => 'and',
          }},
        },
      },
      anyevent => 1,
      cb => sub {
        my (undef, $res) = @_;
        my $result = [];
        if ($res->is_success) {
          my $json = json_bytes2perl $res->content;
          push @$result, map { {id => $_->{_id}, score => $_->{_score}, title => $_->{fields}->{title}->[0]} } @{$json->{hits}->{hits}};
        }
        $cv->send ($result);
      };
  return $cv->recv;
} # search

1;
