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

sub _tc ($) {
  my @node = ($_[0]);
  my @result;
  while (@node) {
    my $node = shift @node;
    my $ln = $node->local_name;
    if (defined $ln) {
      if ({map { $_ => 1 } qw(
        p dt dd li insert delete h1 td th pre rt comment-p ed nsuri
      )}->{$ln}) {
        push @result, "\n";
        unshift @node, $node->child_nodes->to_list;
      } else {
        unshift @node, $node->child_nodes->to_list;
      }
    } elsif ($node->node_type == $node->TEXT_NODE) {
      push @result, $node->text_content;
    }
  }
  return join "", @result;
} # _tc

sub update ($$$$) {
  my ($self, $id, $title, $doc) = @_;
  my $text = ($title // '') . "\n" . _tc $doc->document_element;
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
  $word =~ s/\s+/ /g;
  $word =~ s/^ //;
  $word =~ s/ $//;

  ## <http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-query-string-query.html>
  $word =~ s{([+\-=&|><!(){}\[\]^"~*?:\\/])}{\\$1}g;

  my $url_prefix = $self->url_prefix;
  my $cv = AE::cv;
  http_post_data
      url => qq<$url_prefix/i/_search?fields=title>,
      basic_auth => $self->basic_auth,
      content => perl2json_bytes {
        query => {
          query_string => {
            query => $word,
            default_field => 'content',
          },
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
