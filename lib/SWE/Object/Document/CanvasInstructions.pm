package SWE::Object::Document::CanvasInstructions;
use strict;
use warnings;
use base qw(SWE::Object::Document);

sub to_html_fragment ($;%) {
  my $self = shift;

  require Message::DOM::DOMImplementation;
  my $dom = Message::DOM::DOMImplementation->new;
  my $html_doc = $dom->create_document;
  $html_doc->strict_error_checking (0);
  $html_doc->dom_config->set_parameter
      ('http://suika.fam.cx/www/2006/dom-config/strict-document-children' => 0);
  $html_doc->manakai_is_html (1);

  my $html_container = $html_doc->create_element ('figure');
  $html_container->inner_html (q{<canvas class=swe-canvas-instructions><script type="image/x-canvas-instructions+text"></script></canvas>});
  my $text = $self->to_text;
  if ($$text =~ m[</[Ss][Cc][Rr][Ii][Pp][Tt]]) {
    return ($html_doc, undef)
  } else {
    $html_container->first_child->first_child->text_content ("<!--$$text-->");
    return ($html_doc, $html_container);
  }
} # to_html_fragment

1;
