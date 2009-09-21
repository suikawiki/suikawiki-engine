package SWE::Object::Node;
use strict;
use warnings;

sub new ($%) {
  my $class = shift;
  my $self = bless {@_}, $class;

  return $self;
} # new

sub db ($) { $_[0]->{db} }

sub repo ($) { $_[0]->{repo} }

sub create ($%) {
  my ($self, %opt) = @_;
  $self->{id} = $opt{id};
} # create

sub load ($%) {
  my ($self, %opt) = @_;
  $self->{id} = $opt{id};
} # load

sub id ($) { $_[0]->{id} }

sub prop ($) {
  my $self = shift;

  ## TODO: lock
  
  return $self->{prop} ||= do {
    my $graph_prop_db = $self->db->graph_prop;
    $graph_prop_db->get_data ($self->id) || {};
  };
} # prop

sub save_prop ($) {
  my $self = shift;

  return unless defined $self->{prop};
  
  ## TODO: lock
  
  my $graph_prop_db = $self->db->graph_prop;
  $graph_prop_db->set_data ($self->id => $self->prop);
} # save_prop

sub neighbor_ids ($) {
  my $self = shift;
  
  return $self->prop->{neighbors} || {};
} # neighbor_ids

sub document_id ($) {
  my $self = shift;
  
  return [keys %{$self->prop->{ids} or {}}]->[0];
} # document_id

sub neighbor_documents ($) {
  my $self = shift;

  my $db = $self->db;
  my $doc_id = $self->document_id;

  my $graph = $self->repo->graph;

  require SWE::Object::Document;
  return [map {
    SWE::Object::Document->new (db => $db, id => $_)
  } grep { $_ } map {
    $graph->get_node_by_id ($_)->document_id
  } keys %{$self->neighbor_ids}];
} # neighbor_documents

1;
