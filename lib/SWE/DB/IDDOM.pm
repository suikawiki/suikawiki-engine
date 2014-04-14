package SWE::DB::IDDOM;
use strict;

require SWE::DB::IDProps;
push our @ISA, 'SWE::DB::IDProps';
use Web::DOM::Document;

sub new ($) {
  my $self = shift->SUPER::new (@_);
  $self->{leaf_suffix} = '.dom';
  return $self;
} # new

sub get_data ($$) {
  my $self = shift;
  my $file_name = $self->_get_file_name ($_[0]);

  unless (-f $file_name) {
    return undef;
  }

  open my $file, '<:encoding(utf8)', $file_name or die "$0: $file_name: $!";
  return _load_dom ($file);
} # get_data

sub set_data ($$$) {
  my $self = shift;
  my $file_name = $self->_get_file_name ($_[0], 1);
  my $dom = $_[1];
  
  my $has_file = -f $file_name;
  
  open my $file, '>:encoding(utf8)', $file_name or die "$0: $file_name: $!";
  _store_dom ($file, $dom);

## TODO: cvs
} # set_data

sub _load_dom ($) {
  my $handle = shift;

  my @node = (new Web::DOM::Document);

  $node[0]->strict_error_checking (0);
  $node[0]->dom_config->set_parameter
    ('http://suika.fam.cx/www/2006/dom-config/strict-document-children' => 0);

  my $unescape = sub {
    my $s = shift;
    $s =~ s/\\([0-9A-Fa-f]{2})/pack 'C', hex $1/ge;
    return $s;
  }; # $unescape

  while (<$handle>) {
    tr/\x0D\x0A//d;
    if (s/^n(\d+);//) {
      $node[$1] = $unescape->($_);
    } elsif (s/^t(\d+);//) {
      my $parent_id = $1;
      $node[$parent_id]->append_child
          ($node[0]->create_text_node ($unescape->($_)));
    } elsif (s/^e(\d+);(\d+);(\d+);//) {
      my ($this_id, $parent_id, $ns_id) = ($1, $2, $3);
      $node[$this_id] = $node[0]->create_element_ns
          ($node[$ns_id], [undef, $unescape->($_)]);
      $node[$parent_id]->append_child ($node[$this_id]);
    } elsif (s/^a(\d+);(\d+);([^;]+);//) {
      my ($parent_id, $ns_id, $ln) = ($1, $2, $3);
      $node[$parent_id]->set_attribute_ns
          ($node[$ns_id], [undef, $unescape->($ln)], $unescape->($_));
    }
  }

  return $node[0];
} # _load_dom

sub _store_dom ($$) {
  my $handle = shift;
  my @item = ([0, shift]);

  my $escape = sub {
    my $v = $_[0];
    $v =~ s/([;\\\x0D\x0A])/sprintf '\\%02X', ord $1/ge;
    return $v;
  }; # $escape

  my $ns;
  my $next_id = 1;
  while (@item) {
    my ($parent_id, $node) = @{shift @item};
    if ($node->node_type == $node->ELEMENT_NODE) {
      my $nsuri = $node->namespace_uri // '';
      my $nsid = $ns->{$nsuri};
      unless (defined $nsid) {
        $nsid = $next_id++;
        $ns->{$nsuri} = $nsid;
        print $handle "n", $nsid, ';', $escape->($nsuri), "\n";
      }
      my $el_id = $next_id++;
      print $handle "e", $el_id, ';', $parent_id, ';', $nsid, ';',
          $escape->($node->manakai_local_name), "\n";
      for my $attr (@{$node->attributes}) {
        my $nsuri = $attr->namespace_uri // '';
        my $nsid = $ns->{$nsuri};
        unless (defined $nsid) {
          $nsid = $next_id++;
          $ns->{$nsuri} = $nsid;
          print $handle "n", $nsid, ';', $escape->($nsuri), "\n";
        }
        print $handle "a", $el_id, ';', $nsid, ';', 
            $escape->($attr->manakai_local_name), ';',
            $escape->($attr->value), "\n";
      }
      unshift @item, map {[$el_id, $_]} @{$node->child_nodes}; 
    } elsif ($node->node_type == $node->TEXT_NODE or
             $node->node_type == $node->CDATA_SECTION_NODE) {
      print $handle "t", $parent_id, ';', $escape->($node->data), "\n";
    } elsif ($node->node_type == $node->DOCUMENT_NODE or
             $node->node_type == $node->DOCUMENT_FRAGMENT_NODE) {
      unshift @item, map {[0, $_]} @{$node->child_nodes}; 
    }
  }
} # _store_dom

1;
