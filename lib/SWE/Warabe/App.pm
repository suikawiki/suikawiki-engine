package SWE::Warabe::App;
use strict;
use warnings;
use Warabe::App;
push our @ISA, qw(Warabe::App);
use Wanage::URL qw(percent_encode_c);

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

sub name_url ($$;$) {
  my (undef, $name, $id) = @_;
  my $url = q</n/> . (percent_encode_c $name);
  $url .= '$' . (0+$id) if defined $id;
  return $url;
} # name_url

1;
