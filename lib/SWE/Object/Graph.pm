package SWE::Object::Graph;
use strict;
use warnings;

sub new ($%) {
  my $class = shift;
  my $self = bless {@_}, $class;

  return $self;
}

## ------ Database ------

sub db ($) { $_[0]->{db} }

sub repo ($) { $_[0]->{repo} }

sub lock () {
  my $self = shift;

  if ($self->{lock_n}++ == 0) {
    my $lock = $self->{lock} ||= do {
      require SWE::DB::Lock;
      my $lock = SWE::DB::Lock->new;
      $lock->{file_name} = $self->db->graph_dir_name . 'graph.lock';
      $lock->lock_type ('Graph');
      $lock;
    };

    $lock->lock;
  };
} # lock

sub unlock () {
  my $self = shift;
  
  if (--$self->{lock_n} <= 0 and $self->{lock}) {
    $self->{lock}->unlock;
  }
} # unlock

use constant EMPTY_NODE_RATIO => 0.2;
use constant INITIAL_DEGREE => 5;

sub add_nodes ($$) {
  my ($self, $new_doc_number) = @_;

  $self->lock;

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

  $self->unlock;

  return ($last_node_index + 1 .. $max_node_index);
} # add_nodes

sub create_node ($$) {
  my ($self, $doc_id) = @_;

  ## In fact we don't need to lock the entire graph (though the
  ## |add_nodes| method might require it anyway), but we don't have
  ## way to lock a particular node only at the moment.
  $self->lock;

  my ($node_id) = $self->add_nodes (1);

  require SWE::Object::Node;
  my $node = SWE::Object::Node->new (db => $self->db, repo => $self->repo);
  $node->create (id => $node_id);
  $node->prop->{ids}->{$doc_id} = 1;
  $node->save_prop;

  $self->unlock;

  return $node;
} # create_node

sub get_node_by_id ($$) {
  my ($self, $node_id) = @_;
  
  ## TODO: cache
  
  require SWE::Object::Node;
  my $node = SWE::Object::Node->new (db => $self->db, repo => $self->repo);
  $node->load (id => $node_id);

  return $node;
} # get_node_by_id

use constant RELATEDNESS_THRESHOLD => 0.9;

sub schelling_update ($$) {
  my ($self, $node_id) = @_;

  $self->lock;

  my $node = $self->get_node_by_id ($node_id);
  my $doc_id = $node->document_id // return;

  require SWE::Object::Repository;
  my $repo = SWE::Object::Repository->new (db => $self->db);

  my $related = 0;
  my $n = 0;
  
  my $neighbor_ids = $node->neighbor_ids;
  my $unused_nodes = [];
  for my $n_node_id (keys %$neighbor_ids) {
    $n++;
    my $n_node = $self->get_node_by_id ($n_node_id);
    my $n_doc_id = $n_node->document_id;
    unless (defined $n_doc_id) {
      push @$unused_nodes, $n_node;
      next;
    }
    $related++ if $repo->are_related_ids ($node_id, $n_doc_id);
  }

  my $v = 0;
  if ($n) {
    $v = $related / $n;
  }

  if ($v < RELATEDNESS_THRESHOLD and @$unused_nodes) {
    my $unused_node = $unused_nodes->[rand @$unused_nodes];

    my $id_prop_db = $self->db->id_prop;
    my $id_prop = $id_prop_db->get_data ($doc_id);
    
    $id_prop->{node_id} = $unused_node->id;
    $unused_node->prop->{ids}->{$doc_id} = 1;
    delete $node->prop->{ids}->{$doc_id};

    $unused_node->save_prop;
    $id_prop_db->set_data ($doc_id => $id_prop);
    $node->save_prop;
  }

  $self->unlock;
} # schelling_update

1;
