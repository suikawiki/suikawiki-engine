package SWE::Object::Graph;
use strict;
use warnings;

sub new ($%) {
  my $class = shift;
  my $self = bless {@_}, $class;

  return $self;
}

sub db { $_[0]->{db} }

use constant EMPTY_NODE_RATIO => 0.2;
use constant INITIAL_DEGREE => 5;
use constant NODE_CREATION_RATIO => 0.1;

sub add_nodes ($$) {
  my ($self, $new_doc_number) = @_;
  
  ## TODO: graph lock

  my $global_prop_db = $self->db->global_prop;
  
  my $last_node_index = ${$global_prop_db->get_data ('lastnodeindex') || \ 0};
  my $doc_on_node_number = ${$global_prop_db->get_data ('doconnodenumber') || \ 0};
  $doc_on_node_number += $new_doc_number;
  my $max_node_index = $doc_on_node_number / (1 - EMPTY_NODE_RATIO);
  $max_node_index = $last_node_index if $max_node_index < $last_node_index;
  $max_node_index = $last_node_index + $new_doc_number
      if $max_node_index < $last_node_index + $new_doc_number;
  $max_node_index = int $max_node_index;

  if ($last_node_index < $max_node_index) {
    my $new_edges = {};
    
    for my $index1 ($last_node_index + 1 .. $max_node_index) {
      for (1 .. INITIAL_DEGREE) {
        my $index2 = int rand $index1;
        
        $new_edges->{$index1}->{$index2} = 1;
        $new_edges->{$index2}->{$index1} = 1;
      }
    }
    
    my $graph_prop_db = $self->db->graph_prop;
    for my $index1 (keys %$new_edges) {
      my $node = $graph_prop_db->get_data ($index1);
      my $edges = $node->{neighbors} ||= {};
      for my $index2 (keys %{$new_edges->{$index1}}) {
        $edges->{$index2} = 1;
      }
      $graph_prop_db->set_data ($index1 => $node);
    }

    $global_prop_db->set_data (lastnodeindex => \$max_node_index);
  }
  $global_prop_db->set_data (doconnodenumber => \$doc_on_node_number);

  return ($last_node_index + 1 .. $max_node_index);
} # add_nodes

sub create_node ($$) {
  my ($self, $doc_id) = @_;

  ## TODO: docid lock
  
  my ($node_id) = $self->add_nodes (1);

  require SWE::Object::Node;
  my $node = SWE::Object::Node->new (db => $self->db);
  $node->create (id => $node_id);
  $node->prop->{ids}->{$doc_id} = 1;
  $node->save_prop;

  return $node;
} # create_node

sub get_node_by_id ($$) {
  my ($self, $node_id) = @_;
  
  ## TODO: cache
  
  require SWE::Object::Node;
  my $node = SWE::Object::Node->new (db => $self->db);
  $node->load (id => $node_id);

  return $node;
} # get_node_by_id

1;
