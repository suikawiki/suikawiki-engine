package SWE::Lang;
use strict;
use warnings;
use Exporter::Lite;

our @EXPORT_OK = qw(@ContentMediaType %ContentMediaType);

our @ContentMediaType =
(
  {type => 'text/x-suikawiki', module => 'SWE::Lang::SWML',
   label => 'SWML'},
  {type => 'text/x.suikawiki.image', module => 'SWE::Lang::SWML'},
  {type => 'application/x.suikawiki.config'},
  {type => 'text/plain', label => 'Plain text'},
  {type => 'image/x-canvas-instructions+text',
   module => 'SWE::Lang::CanvasInstructions',
   label => 'Drawing'},
  {type => 'text/css', label => 'CSS'},
);
our %ContentMediaType = map { $_->{type} => $_ } @ContentMediaType;

1;
