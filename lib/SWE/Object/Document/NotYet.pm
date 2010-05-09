package SWE::Object::Document::NotYet;
use strict;
use warnings;
use base qw(SWE::Object::Document);

sub prop ($) {
  return {};
} # prop

sub to_text_media_type ($) {
  return undef;
} # to_text_media_type

sub to_xml_media_type ($) {
  return undef;
} # to_xml_media_type

1;
