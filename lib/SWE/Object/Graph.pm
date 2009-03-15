package SWE::Object::Graph;
use strict;
use warnings;

sub new ($%) {
  my $class = shift;
  my $self = bless {@_}, $class;

  return $self;
}

sub db : lvalue { $_[0]->{db} }

use constant EMPTY_NODE_RATIO => 0.2;
use constant INITIAL_DEGREE => 5;

sub add_nodes ($$) {
  my ($self, $new_doc_number) = @_;
  
  ## TODO: graph lock

  my $global_prop_db = $self->db->global_prop;
  
  my $last_node_index = ${$global_prop_db->get_data ('lastnodeindex') || \ 0};
  my $max_node_index = int ($last_node_index + $new_doc_number / (1 - EMPTY_NODE_RATIO)) + 1;
      
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

  return ($last_node_index + 1 .. $max_node_index);
} # add_nodes

sub create_node ($$) {
  my ($self, $doc_id) = @_;

  ## TODO: docid lock
  
  my ($node_id) = $self->add_nodes (1);
  
  my $graph_prop_db = $self->db->graph_prop;
  my $node_prop = $graph_prop_db->get_data ($node_id);
  $node_prop->{ids}->{$doc_id} = 1;
  $graph_prop_db->set_data ($node_id => $node_prop);

  return {id => $node_id}; ## TODO: SWE::Object::Node
} # create_node

1;
