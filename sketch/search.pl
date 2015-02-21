use strict;
use warnings;
use AnyEvent;
use Web::UserAgent::Functions;
use JSON::Functions::XS qw(perl2json_bytes json_bytes2perl);
use Data::Dumper;

my $url_prefix = shift;
my $auth;
if ($url_prefix =~ s{^https://([^\@:]+):([^\@:]+)\@}{https://}) {
  $auth = [$1, $2];
}


{
my $url = qq<$url_prefix/test/docs/3>;

my $cv = AE::cv;

use utf8;
http_post
    override_method => 'PUT',
    anyevent => 1,
    url => $url,
    basic_auth => $auth,
    content => perl2json_bytes {
      content => "bc def",
    },
    cb => sub {
      my (undef, $res) = @_;
      if ($res->is_success < 400) {
        $cv->send (json_bytes2perl $res->content);
      } else {
        die $res->code;
      }
    };

warn $cv->recv;
}


{
my $url = qq<$url_prefix/test/docs/_search>;

my $cv = AE::cv;

use utf8;
http_post
    anyevent => 1,
    url => $url,
    basic_auth => $auth,
    content => perl2json_bytes {
      query => {
        match => {
                 content => {query => "えあう", operator => 'and'},
                },
      },
    },
    cb => sub {
      my (undef, $res) = @_;
      if ($res->is_success < 400) {
        $cv->send (json_bytes2perl $res->content);
      } else {
        die $res->code;
      }
    };

warn Dumper $cv->recv;
}
