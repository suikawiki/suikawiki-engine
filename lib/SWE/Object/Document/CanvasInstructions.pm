package SWE::Object::Document::CanvasInstructions;
use strict;
use warnings;
use base qw(SWE::Object::Document);
use Web::DOM::Document;

sub to_html_fragment ($;%) {
  my $self = shift;

  my $html_doc = new Web::DOM::Document;
  $html_doc->strict_error_checking (0);
  $html_doc->dom_config->set_parameter
      ('http://suika.fam.cx/www/2006/dom-config/strict-document-children' => 0);
  $html_doc->manakai_is_html (1);

  my $html_container = $html_doc->create_element ('figure');
  $html_container->inner_html (q{<canvas class=swe-canvas-instructions><script type="image/x-canvas-instructions+text"></script></canvas>});
  my $text = $self->to_text;
  $$text =~ s/\x0D\x0A/\x0A/g;
  $$text =~ s/\x0D/\x0A/g;
  $html_container->first_child->first_child->text_content ("<!--$$text-->");
  $html_container->inner_html ($html_container->inner_html);
  if ($html_container->first_child->first_child->text_content eq "<!--$$text-->") {
    return ($html_doc, $html_container);
  } else {
    return ($html_doc, undef)
  }
} # to_html_fragment

1;
