package SWE::Lang::XML2HTML;
use strict;
use warnings;
use Wanage::URL qw(percent_encode_c);

our $ConverterVersion = 6;

sub AA_NS () { q<http://pc5.2ch.net/test/read.cgi/hp/1096723178/aavocab#> }
sub HTML_NS () { q<http://www.w3.org/1999/xhtml> }
sub SW09_NS () { q<urn:x-suika-fam-cx:markup:suikawiki:0:9:> }
sub SW10_NS () { q<urn:x-suika-fam-cx:markup:suikawiki:0:10:> }
sub XML_NS () { q<http://www.w3.org/XML/1998/namespace> }
sub MATH_NS () { q<http://www.w3.org/1998/Math/MathML> }
sub HTML3_NS () { q<urn:x-suika-fam-cx:markup:ietf:html:3:draft:00:> }

my $templates = {};

my $IsImplicitLinkElement = {};

$templates->{''}->{''} = sub {
  my ($items, $item) = @_;

  if ($item->{node}->node_type == $item->{node}->ELEMENT_NODE) {
    unshift @$items,
        map {{%$item, node => $_, parent => $item->{parent}}}
        @{$item->{node}->child_nodes};
  } else {
    $item->{parent}->manakai_append_text ($item->{node}->node_value);
  }
};

$templates->{(HTML_NS)}->{head} = sub { };

$templates->{(HTML_NS)}->{section} = sub {
  my ($items, $item) = @_;

  my $section_el = $item->{doc}->create_element_ns (HTML_NS, 'section');
  $section_el->set_attribute (class => 'section sw-section');
  $item->{parent}->append_child ($section_el);

  my $id;
  for (@{$item->{node}->children}) {
    if ($_->local_name eq 'h1') {
      $id = $_->text_content;
      last;
    }
  }
  if (defined $id) {
    $id =~ s/\s+/ /g;
    $id =~ s/^ //;
    $id =~ s/ $//;
    $id =~ s/[\x09\x0A\x0D\x20]/-/g; ## HTML "space character"
    $id = defined $item->{section_id}
        ? $item->{section_id} . "\x{2028}" . $id : 'section-' . $id;
    $section_el->set_attribute (id => $id);
  }

  unshift @$items,
      map {{%$item, node => $_, parent => $section_el,
            section_id => defined $id ? $id : $item->{section_id},
            heading_level => $item->{heading_level} + 1}}
      @{$item->{node}->child_nodes};
};

$templates->{(HTML_NS)}->{h1} = sub {
  my ($items, $item) = @_;

  my $h_el = $item->{doc}->create_element_ns (HTML_NS, 'h1');
  $h_el->set_attribute (id => "header-$item->{section_id}")
      if defined $item->{section_id};
  $item->{parent}->append_child ($h_el);

  unshift @$items,
      map {{%$item, node => $_, parent => $h_el}}
      @{$item->{node}->child_nodes};
};

$templates->{(HTML_NS)}->{$_} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns
      (HTML_NS, $item->{node}->manakai_local_name);
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
} for qw/
  p ul ol dl li dt dd table tbody tr blockquote pre
  dfn samp span sub sup var em strong
  b i u
/;

$templates->{(HTML_NS)}->{$_} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns
      (HTML_NS, $item->{node}->manakai_local_name);
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  my $parent = $el;
  if ($item->{node}->has_attribute ('data-implicit-link')) {
    $parent = $item->{doc}->create_element ('a');
    $parent->set_attribute (class => 'sw-anchor');
    my $name = $item->{node}->get_attribute ('data-title');
    $name = $item->{node}->text_content unless length $name;
    my $url = $item->{name_to_url}->($name);
    $parent->href ($url);
    if ($item->{node}->local_name eq 'cite') {
      $parent->rel ('nofollow');
    }
    $el->append_child ($parent);
  }

  unshift @$items,
      map {{%$item, node => $_, parent => $parent}}
      @{$item->{node}->child_nodes};
} for qw/
  code abbr cite kbd
/;
$IsImplicitLinkElement->{(HTML_NS)}->{$_} = 1 for qw/
  code abbr cite kbd
/;

$templates->{(SW09_NS)}->{asis} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'mark');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class = defined $class ? 'sw-asis ' . $class : 'sw-asis';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
}; # asis

$templates->{(SW09_NS)}->{dotabove} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'ruby');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class = defined $class ? 'sw-dotabove ' . $class : 'sw-dotabove';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  my $rt = $item->{doc}->create_element_ns (HTML_NS, 'rt');
  $rt->text_content ("\x{30FB}");

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes}, $rt;
}; # dotabove

$templates->{(SW09_NS)}->{vector} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'ruby');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class = defined $class ? 'sw-vector ' . $class : 'sw-vector';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  my $rt = $item->{doc}->create_element_ns (HTML_NS, 'rt');
  $rt->text_content ("\x{2192}");

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes}, $rt;
}; # vector

$templates->{(SW09_NS)}->{snip} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'ins');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class = defined $class ? 'sw-snip ' . $class : 'sw-snip';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
}; # snip

$templates->{(SW09_NS)}->{emph} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'em');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
}; # emph

$templates->{(HTML_NS)}->{$_} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns
      (HTML_NS, $item->{node}->manakai_local_name);
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  my $colspan = $item->{node}->get_attribute ('colspan');
  $el->set_attribute (colspan => $colspan) if defined $colspan;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
} for qw/th td/;

$templates->{(HTML_NS)}->{rt} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'rp');
  $el->text_content (' (');
  $item->{parent}->append_child ($el);

  $el = $item->{doc}->create_element_ns
      (HTML_NS, $item->{node}->manakai_local_name);
  $item->{parent}->append_child ($el);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};

  $el = $item->{doc}->create_element_ns (HTML_NS, 'rp');
  $el->text_content (') ');
  $item->{parent}->append_child ($el);
};

$templates->{(SW09_NS)}->{insert} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'ins');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW09_NS)}->{delete} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'del');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW09_NS)}->{refs} =
$templates->{(SW09_NS)}->{example} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'div');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class') // '';
  $el->set_attribute (class => $class . ' sw-' . $item->{node}->manakai_local_name);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
}; # refs

$templates->{(HTML_NS)}->{figure} =
$templates->{(HTML_NS)}->{figcaption} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns
      (HTML_NS, $item->{node}->manakai_local_name);
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
}; # figcaption

$templates->{(SW09_NS)}->{history} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'div');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class') // '';
  $class .= ' sw-history';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
}; # history

$templates->{(HTML3_NS)}->{'note'} =
$templates->{(SW10_NS)}->{'comment-p'} =
$templates->{(SW09_NS)}->{'preamble'} =
$templates->{(SW09_NS)}->{'postamble'} =
$templates->{(SW10_NS)}->{'ed'} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'div');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class') // '';
  $class .= ' sw-note-block sw-' . $item->{node}->local_name;
  $el->set_attribute (class => $class);

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW09_NS)}->{'talk'} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns
      (HTML_NS, 'sw-' . $item->{node}->local_name);
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class') // '';
  $el->set_attribute (class => $class);

  my @child = @{$item->{node}->child_nodes};
  my $has_speaker = 0;
  for (@child) {
    if ($_->node_type == $_->ELEMENT_NODE and $_->local_name eq 'speaker') {
      $has_speaker = 1;
    }
  }
  $el->class_list->add ('sw-talk-no-speaker') unless $has_speaker;

  unshift @$items, map {{%$item, node => $_, parent => $el}} @child;
};

$templates->{(SW09_NS)}->{'dialogue'} =
$templates->{(SW09_NS)}->{'speaker'} =
$templates->{(SW09_NS)}->{'smallcaps'} =
$templates->{(SW09_NS)}->{'lines'} =
$templates->{(SW09_NS)}->{'line'} =
$templates->{(SW09_NS)}->{'openfence'} =
$templates->{(SW09_NS)}->{'fencedtext'} =
$templates->{(SW09_NS)}->{'closefence'} =
$templates->{(SW09_NS)}->{'box'} =
$templates->{(SW09_NS)}->{'yoko'} =
$templates->{(SW09_NS)}->{'subsup'} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns
      (HTML_NS, 'sw-' . $item->{node}->local_name);
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class') // '';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW09_NS)}->{'sw-see'} =
$templates->{(SW09_NS)}->{'sw-macron'} =
$templates->{(SW09_NS)}->{'sw-tate'} =
$templates->{(SW09_NS)}->{'sw-mirrored'} =
$templates->{(SW09_NS)}->{'sw-l'} =
$templates->{(SW09_NS)}->{'sw-r'} =
$templates->{(SW09_NS)}->{'sw-v'} =
$templates->{(SW09_NS)}->{'sw-vb'} =
$templates->{(SW09_NS)}->{'sw-lt'} =
$templates->{(SW09_NS)}->{'sw-rt'} =
$templates->{(SW09_NS)}->{'sw-vt'} =
$templates->{(SW09_NS)}->{'sw-vbt'} =
$templates->{(SW09_NS)}->{'sw-vrl'} =
$templates->{(SW09_NS)}->{'sw-vlr'} =
$templates->{(SW09_NS)}->{'sw-left'} =
$templates->{(SW09_NS)}->{'sw-right'} =
$templates->{(SW09_NS)}->{'sw-vrlbox'} =
$templates->{(SW09_NS)}->{'sw-vlrbox'} =
$templates->{(SW09_NS)}->{'sw-leftbox'} =
$templates->{(SW09_NS)}->{'sw-rightbox'} =
$templates->{(SW09_NS)}->{'sw-leftbtbox'} =
$templates->{(SW09_NS)}->{'sw-rightbtbox'} =
$templates->{(SW09_NS)}->{'sw-cursive'} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, $item->{node}->local_name);
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
}; # sw-see

$templates->{(SW09_NS)}->{'fenced'} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns
      (HTML_NS, 'sw-' . $item->{node}->local_name);
  $item->{parent}->append_child ($el);

  my @children = @{$item->{node}->child_nodes};
  my $max_lines = 0;
  for (@children) {
    if ($_->node_type == $_->ELEMENT_NODE and
        $_->local_name eq 'fencedtext') {
      for (grep { $_->local_name eq 'lines' } @{$_->children}) {
        my $lines = 0;
        for (@{$_->children}) {
          $lines++ if $_->local_name eq 'line';
        }
        $max_lines = $lines if $max_lines < $lines;
      }
    }
  }
  $el->set_attribute ('data-fence-size' => $max_lines);

  my $class = $item->{node}->get_attribute ('class') // '';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}} @children;
};

$templates->{(AA_NS)}->{aa} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'span');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-aa';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW10_NS)}->{csection} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'cite');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-csection';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW10_NS)}->{key} = sub {
  my ($items, $item) = @_;

  my $el0 = $item->{doc}->create_element_ns (HTML_NS, 'kbd');
  $item->{parent}->append_child ($el0);

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'kbd');
  $el0->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  my $parent = $el;
  if ($item->{node}->has_attribute ('data-implicit-link')) {
    $parent = $item->{doc}->create_element ('a');
    $parent->set_attribute (class => 'sw-anchor');
    my $name = $item->{node}->get_attribute ('data-title');
    $name = $item->{node}->text_content unless length $name;
    my $url = $item->{name_to_url}->($name);
    $parent->href ($url);
    $el->append_child ($parent);
  }

  unshift @$items,
      map {{%$item, node => $_, parent => $parent}}
      @{$item->{node}->child_nodes};
};
$IsImplicitLinkElement->{(SW10_NS)}->{key} = 1;

$templates->{(SW10_NS)}->{qn} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'code');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-qn';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(HTML_NS)}->{hr} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'hr');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW10_NS)}->{src} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'cite');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-src';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW09_NS)}->{weak} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'small');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-weak';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW09_NS)}->{subscript} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'sub');
  $item->{parent}->append_child ($el);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
}; # subscript

$templates->{(SW09_NS)}->{superscript} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'sup');
  $item->{parent}->append_child ($el);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
}; # superscript

$templates->{(SW09_NS)}->{f} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'span');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-f';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  my $parent = $el;
  if ($item->{node}->has_attribute ('data-implicit-link')) {
    $parent = $item->{doc}->create_element ('a');
    $parent->set_attribute (class => 'sw-anchor');
    my $name = $item->{node}->get_attribute ('data-title');
    $name = $item->{node}->text_content unless length $name;
    my $url = $item->{name_to_url}->($name);
    $parent->href ($url);
    $el->append_child ($parent);
  }

  unshift @$items,
      map {{%$item, node => $_, parent => $parent}}
      @{$item->{node}->child_nodes};
};
$IsImplicitLinkElement->{(SW09_NS)}->{f} = 1;

for my $x (
  [SW09_NS, 'n', 'https://data.suikawiki.org/number/'],
  [SW09_NS, 'tz', 'https://data.suikawiki.org/tzoffset/'],
  [SW09_NS, 'lat', 'https://data.suikawiki.org/lat/'],
  [SW09_NS, 'lon', 'https://data.suikawiki.org/lon/'],
  [HTML_NS, 'time', 'https://data.suikawiki.org/datetime/'],
) {
$templates->{$x->[0]}->{$x->[1]} = sub {
  my ($items, $item) = @_;

  my $name = $item->{node}->get_attribute ('data-title') // '';
  my $has_text = !! length $name;
  $name = $item->{node}->text_content unless length $name;

  my $el_name = 'data';
  my $url_prefix = $x->[2];
  my $url_suffix = '';
  if ($x->[1] eq 'time') {
    if ($name =~ /\Aunix:([0-9]+)\z/) {
      $name = $1;
    } elsif ($name =~ /^[a-zA-Z_-]+:/) {
      #
    } elsif ($name eq '0') {
      $name = '0';
    } elsif ($name =~ /\A(?:year:|)(-?[0-9]+)\z/) {
      $url_prefix = 'https://data.suikawiki.org/y/' . $1 . '/';
      undef $url_suffix;
      $el_name = 'time';
    } elsif ($name =~ /\Ay~([0-9]+)\z/) {
      $url_prefix = 'https://data.suikawiki.org/e/' . $1 . '/';
      undef $url_suffix;
    } else {
      $el_name = 'time';
    }
  } elsif ($x->[1] eq 'tz') {
    $el_name = 'time';
  }
  
  my $el = $item->{doc}->create_element_ns (HTML_NS, $el_name);

  if ($el_name eq 'time') {
    $el->set_attribute ('datetime', $name);
  } else {
    $el->set_attribute ('value', $name);
  }
  
  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-'.$x->[1];
  $class .= ' sw-has-text' if $has_text;
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  if ($item->{node}->has_attribute ('data-implicit-link')) {
    my $link = $item->{doc}->create_element ('a');
    $link->set_attribute (class => 'sw-anchor');
    if (not defined $url_suffix) {
      $link->href ($url_prefix);
    } else {
      $link->href ($url_prefix . (percent_encode_c $name) . $url_suffix);
    }
    $link->append_child ($el);
    $item->{parent}->append_child ($link);
  } else {
    $item->{parent}->append_child ($el);
  }

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};
$IsImplicitLinkElement->{$x->[0]}->{$x->[1]} = 1;
}

for my $kwd (qw(MUST SHOULD MAY)) {$templates->{(SW09_NS)}->{$kwd} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'em');
  $el->title ($kwd);
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' rfc2119 sw-'.$kwd;
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  my $parent = $item->{doc}->create_element ('a');
  $parent->class_name ('sw-anchor');
  $parent->href ($item->{name_to_url}->($kwd));
  $el->append_child ($parent);

  unshift @$items,
      map {{%$item, node => $_, parent => $parent}}
      @{$item->{node}->child_nodes};
}}

$templates->{(SW10_NS)}->{title} = sub {
  my ($items, $item) = @_;
  unless ($item->{parent}->has_attribute ('title')) {
    $item->{parent}->set_attribute (title => $item->{node}->text_content);
  }
};

$templates->{(SW10_NS)}->{attrvalue} = sub {
  my ($items, $item) = @_;
  if (defined $item->{data_element}) {
    if ($item->{data_element}->local_name eq 'time') {
      if (not $item->{data_element}->has_attribute ('datetime')) {
        $item->{data_element}->set_attribute
            (datetime => $item->{node}->text_content);
      }
    } else {
      if (not $item->{data_element}->has_attribute ('value')) {
        $item->{data_element}->set_attribute
            (value => $item->{node}->text_content);
      }
    }
  }
};

$templates->{(SW10_NS)}->{nsuri} = sub {
  my ($items, $item) = @_;

  unless ($item->{parent}->has_attribute ('title')) {
    $item->{parent}->set_attribute
        (title => '<' . $item->{node}->text_content . '>');
  }
};

$templates->{(HTML_NS)}->{q} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns
      (HTML_NS, $item->{node}->manakai_local_name);
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $el->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  if ($item->{node}->has_attribute_ns (SW09_NS, 'resScheme')) {
    ## TODO: ...
  }

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};
$templates->{(HTML_NS)}->{del} = $templates->{(HTML_NS)}->{q};
$templates->{(HTML_NS)}->{ins} = $templates->{(HTML_NS)}->{q};

$templates->{(HTML_NS)}->{ruby} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'ruby');
  $item->{parent}->append_child ($el);

  my @children = @{$item->{node}->child_nodes};
  my @rt = grep { ($_->local_name || '') eq 'rt' } @children;
  my $both = @rt >= 2;

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-ruby';
  $class .= ' sw-ruby-both' if $both;
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}} @children;
}; # ruby

$templates->{(SW09_NS)}->{rubyb} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'ruby');
  $item->{parent}->append_child ($el);

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-rubyb';
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
}; # rubyb

$templates->{(SW09_NS)}->{okuri} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'ruby');
  $item->{parent}->append_child ($el);

  my @children = @{$item->{node}->child_nodes};
  my @rt = grep { ($_->local_name || '') eq 'rt' } @children;
  my $both = @rt >= 2;

  my $class = $item->{node}->get_attribute ('class');
  $class //= '';
  $class .= ' sw-okuri';
  $class .= ' sw-ruby-both' if $both;
  $el->set_attribute (class => $class);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el}} @children;
}; # okuri

$templates->{(MATH_NS)}->{$_} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (MATH_NS, 'math');
  $item->{parent}->append_child ($el);
  $el->set_attribute (class => 'sw-' . substr $item->{node}->local_name, 1);

  my $el2 = $item->{doc}->create_element_ns (MATH_NS, $item->{node}->local_name);
  $el->append_child ($el2);

  my $class = $item->{node}->get_attribute ('class');
  $el2->set_attribute (class => $class) if defined $class;

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el2->set_attribute (lang => $lang) if defined $lang;

  unshift @$items,
      map {{%$item, node => $_, parent => $el2}}
      @{$item->{node}->child_nodes};
} for qw(mfrac mroot msqrt munderover munder);

$templates->{(MATH_NS)}->{mtext} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (MATH_NS, 'mtext');
  $item->{parent}->append_child ($el);

  my $lang = $item->{node}->get_attribute_ns (XML_NS, 'lang');
  $el->set_attribute (lang => $lang) if defined $lang;

  my $el2 = $item->{doc}->create_element_ns (HTML_NS, 'span');
  $el->append_child ($el2);

  unshift @$items,
      map {{%$item, node => $_, parent => $el2}}
      @{$item->{node}->child_nodes};
}; # mtext

$templates->{(SW09_NS)}->{anchor} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'a');
  $item->{parent}->append_child ($el);
  $el->set_attribute (class => 'sw-anchor');

  my $name;

  my @child = @{$item->{node}->child_nodes};
  for my $node (@child) {
    if ($node->node_type == 1 and
        $node->local_name eq 'title' and
        $node->namespace_uri eq SW10_NS) {
      $name = $node->text_content;
      last;
    }
  }
  
  if (not defined $name) {
    $name = $item->{node}->text_content;
    if ($name eq '//') {
      $name = 'HomePage'; ## Don't use $homepage_name - this is not configurable
    } elsif ($name =~ s!^\.//!!) {
      $name = $item->{name} . '//' . $name;
    } elsif ($name =~ s!^\.\.//!!) {
      my $pname = $item->{name};
      $pname =~ s<//(?:(?!//).)+$><>;
      $name = $pname . '//' . $name;
    }

    $name =~ s/\s+/ /g;
    $name =~ s/^ //;
    $name =~ s/ $//;
    $name = 'HomePage' unless length $name;
  }

  my $url = $item->{name_to_url}->($name);

  my $anchor = $item->{node}->get_attribute_ns (SW09_NS, 'anchor');
  if (defined $anchor) {
    $url .= '#anchor-' . $anchor;
    my $t = $item->{doc}->create_text_node (' (>>' . $anchor . ')');
    unshift @$items, {%$item, node => $t, parent => $el};
  }
  
  $el->set_attribute (href => $url);

  unshift @$items,
      map {{%$item, node => $_, parent => $el}} @child;
};

$templates->{(SW09_NS)}->{'anchor-internal'} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'a');
  $item->{parent}->append_child ($el);
  $el->set_attribute (class => 'sw-anchor-internal');

  my $id = $item->{node}->get_attribute_ns (SW09_NS, 'anchor') + 0;
  $el->set_attribute (href => '#anchor-' . $id);

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW09_NS)}->{'anchor-end'} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'a');
  $item->{parent}->append_child ($el);
  $el->set_attribute (class => 'sw-anchor-end');

  my $id = $item->{node}->get_attribute_ns (SW09_NS, 'anchor') + 0;
  $el->set_attribute (id => 'anchor-' . $id);
  $el->set_attribute (href => '#anchor-' . $id);
  $el->set_attribute (rel => 'bookmark');

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};
};

$templates->{(SW09_NS)}->{'anchor-external'} = sub {
  my ($items, $item) = @_;

  my $container = $item->{doc}->create_element_ns (HTML_NS, 'span');
  $container->set_attribute (class => 'sw-anchor-external-container');

  #$container->manakai_append_text ('<');

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'a');
  $container->append_child ($el);
  $el->set_attribute (class => 'sw-anchor-external');

  #$container->manakai_append_text ('>');

  my $scheme = $item->{node}->get_attribute_ns (SW09_NS, 'resScheme');
  if ($scheme eq 'URI' or $scheme eq 'URL') {
    $el->set_attribute
        (href => $item->{node}->get_attribute_ns (SW09_NS, 'resParameter'));
  } else {
    ## TODO: ...
  }

  unshift @$items,
      map {{%$item, node => $_, parent => $el}}
      @{$item->{node}->child_nodes};

  $item->{parent}->append_child ($container);
}; # anchor-external

$templates->{(SW09_NS)}->{image} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'div');
  $el->set_attribute (class => 'article sw-image');
  $item->{parent}->append_child ($el);

  my $type;
  my $alt;
  my $head_el = $item->{node}->owner_document->manakai_head;
  if ($head_el) {
    for (@{$head_el->child_nodes}) {
      next if $_->node_type != $_->ELEMENT_NODE;
      next if ($_->namespace_uri // '') ne SW09_NS;
      next if $_->manakai_local_name ne 'parameter';
      my $name = $_->get_attribute ('name');
      if ($name eq 'image-type' or $name eq 'image-alt') {
        for (@{$_->child_nodes}) {
          next if $_->node_type != $_->ELEMENT_NODE;
          next if ($_->namespace_uri // '') ne SW09_NS;
          next if $_->manakai_local_name ne 'value';
          if ($name eq 'image-type') {
            $type //= $_->text_content;
          } elsif ($name eq 'image-alt') {
            $alt //= $_->text_content;
          }
          last;
        }
        last if defined $type and defined $alt;
      }
    }
  }
  $type //= 'application/octet-stream';
  $type =~ tr{a-zA-Z0-9.+-_/-}{}cd;
      ## NOTE: '!', '#', '$', '&', '^' are also allowed according to RFC 4288.

  my $data = $item->{node}->text_content;
  $data =~ s/\s+//g;

  my $img_el = $item->{doc}->create_element_ns (HTML_NS, 'img');
  $img_el->set_attribute (alt => $alt // '');
  $img_el->set_attribute (src => 'data:' . $type . ';base64,' . $data);
  $el->append_child ($img_el);
};

$templates->{(SW09_NS)}->{replace} = sub {
  my ($items, $item) = @_;

  my $el = $item->{doc}->create_element_ns (HTML_NS, 'span');
  $el->set_attribute (class => 'sw-replace');
  $el->text_content ($item->{node}->get_attribute ('by') // '');
  $item->{parent}->append_child ($el);
};

sub convert ($$$$$$) {
  shift;
  my $name = shift;
  my $swml = shift;
  my $doc = shift;
  my $name_to_url = shift;
  my $heading_level = shift;

  my $df = $doc->create_document_fragment;

  my @node = ([$swml->document_element, {}]);
  while (@node) {
    my ($node, $flags) = @{shift @node};
    if (not defined $node) {
      if (not $flags->{has_link} and not $flags->{in_link}) {
        $flags->{end_of}->set_attribute ('data-implicit-link', '');
        $flags->{parent_flags}->{has_link} = 1;
      }
      if (defined $flags->{end_of} and defined $flags->{title}) {
        $flags->{end_of}->set_attribute ('data-title', $flags->{title});
      }
      next;
    }
    my $nt = $node->node_type;
    if ($nt == 1) { # ELEMENT_NODE
      my $ln = $node->local_name;
      if (($ln eq 'anchor' or
           $ln eq 'MUST' or
           $ln eq 'SHOULD' or
           $ln eq 'MAY') and $node->namespace_uri eq SW09_NS) {
        $flags->{has_link} = 1;
        my $f = {end_of => $node, parent_flags => $flags,
                 in_link => 1};
        unshift @node, [undef, $f];
        unshift @node, map { [$_, $f] } $node->child_nodes->to_list;
      } elsif ($IsImplicitLinkElement->{$node->namespace_uri}->{$ln}) {
        my $f = {end_of => $node, parent_flags => $flags,
                 in_link => $flags->{in_link}};
        unshift @node, [undef, $f];
        unshift @node, map { [$_, $f] } $node->child_nodes->to_list;
      } elsif (($ln eq 'title' or
                $ln eq 'attrvalue') and $node->namespace_uri eq SW10_NS) {
        $flags->{title} = $node->text_content;
      } else {
        unshift @node, map { [$_, $flags] } $node->child_nodes->to_list;
      }
    #} elsif ($nt == 3) { # TEXT_NODE
    #
    }
  }

  my @items = map {{doc => $doc,
                    name_to_url => $name_to_url,
                    heading_level => $heading_level, name => $name,
                    node => $_, parent => $df}} @{$swml->child_nodes};
  while (@items) {
    my $item = shift @items;
    my $nsuri = $item->{node}->namespace_uri // '';
    my $ln = $item->{node}->manakai_local_name // '';
    my $template = $templates->{$nsuri}->{$ln} || $templates->{''}->{''};
    $template->(\@items, $item);
  }

  return $df;
} # convert

1;

=head1 LICENSE

Copyright 2008-2021 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
