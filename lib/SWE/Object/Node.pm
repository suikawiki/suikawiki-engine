package SWE::Object::Node;
use strict;
use warnings;

sub new ($%) {
  my $class = shift;
  my $self = bless {@_}, $class;

  return $self;
} # new

sub db { $_[0]->{db} }

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

1;
