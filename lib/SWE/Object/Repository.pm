package SWE::Object::Repository;
use strict;
use warnings;
use Scalar::Util qw/weaken/;

sub new ($%) {
  my $class = shift;
  my $self = bless {@_}, $class;

  return $self;
}

sub db ($) { $_[0]->{db} }

sub graph ($) {
  my $self = shift;
  return $self->{graph} ||= do {
    require SWE::Object::Graph;
    my $g = SWE::Object::Graph->new (repo => $self, db => $self->db);
    weaken $g->{repo};
    $g;
  };
} # graph

sub get_document_by_id ($$) {
  my ($self, $doc_id) = @_;

  return $self->{document}->{$doc_id} ||= do {
    require SWE::Object::Document;
    my $doc = SWE::Object::Document->new
        (repo => $self, db => $self->db, id => $doc_id);
    weaken $doc->{repo};
    $doc;
  };
} # get_document_by_id

## ------ The Term Weight Vector ------

sub weight_lock () {
  my $self = shift;

  if ($self->{weight_lock_n}++ == 0) {
    my $lock = $self->{weight_lock} ||= do {
      require SWE::DB::Lock;
      my $lock = SWE::DB::Lock->new;
      $lock->{file_name} = $self->db->global_dir_name . 'weight.lock';
      $lock->lock_type ('Weight');
      $lock;
    };

    $lock->lock;
  };
} # weight_lock

sub weight_unlock () {
  my $self = shift;
  
  if (--$self->{weight_lock_n} <= 0 and $self->{weight_lock}) {
    $self->{weight_lock}->unlock;
  }
} # weight_unlock

sub term_weight_vector ($) {
  my $self = shift;

  return $self->{term_weight_vector} ||= do {
    require SWE::Data::FeatureVector;

    my $global_prop_db = $self->db->global_prop;
    my $w = SWE::Data::FeatureVector->parse_stringref
        ($global_prop_db->get_data ('termweightvector') || \ '');
    delete $self->{term_weight_vector_modified};
    $w;
  };
} # term_weight_vector

sub save_term_weight_vector ($) {
  my $self = shift;
  return unless $self->{term_weight_vector_modified};

  my $global_prop_db = $self->db->global_prop;
  $global_prop_db->set_data
      (termweightvector => \($self->{term_weight_vector}->stringify));
} # save_term_weight_vector

sub are_related_ids ($$$;$) {
  my ($self, $id1, $id2, $answer) = @_;
  
  my $w = $self->term_weight_vector;
  
  my $tfidf_db = $self->db->id_tfidf;

  ## TODO: cache
  
  require SWE::Data::FeatureVector;
  my $fv1 = SWE::Data::FeatureVector->parse_stringref
      ($tfidf_db->get_data ($id1) // return undef);
  my $fv2 = SWE::Data::FeatureVector->parse_stringref
      ($tfidf_db->get_data ($id2) // return undef);
  
  my $diff = $fv1->subtract ($fv2);

  my $i = 0;
  A: {
    my $wx = $diff->multiply ($w)->component_sum;
    my $y = $wx >= 0 ? 1 : -1;
    
    if (defined $answer and $y * $answer < 0) {
      $w = $y > 0 ? $w->subtract ($diff) : $w->add ($diff);
      $self->{term_weight_vector} = $w;
      $self->{term_weight_vector_modified} = 1;
      $i++;
      redo A unless $i > 20;
    }
    
    return $y > 0;
  }
} # are_related_ids

1;
