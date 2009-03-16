package SWE::Object::Repository;
use strict;
use warnings;

sub new ($%) {
  my $class = shift;
  my $self = bless {@_}, $class;

  return $self;
}

sub db ($) { $_[0]->{db} }

my $weight_file_name = 'data/weight.txt';

sub term_weight_vector ($) {
  my $self = shift;

  ## TODO: lock

  ## TODO: use global props

  return $self->{term_weight_vector} ||= do {
    require SWE::Data::FeatureVector;

    my $w;
    if (-f $weight_file_name) {
      local $/ = undef;
      open my $file, '<:encoding(utf8)', $weight_file_name or die "$0: $weight_file_name: $!";
      $w = SWE::Data::FeatureVector->parse_stringref (\<$file>);
      close $file;
    } else {
      $w = SWE::Data::FeatureVector->new;
    }
    delete $self->{term_weight_vector_modified};
    $w;
  };
} # term_weight_vector

sub save_term_weight_vector ($) {
  my $self = shift;
  return unless $self->{term_weight_vector_modified};
  
  ## TODO: use global props
  
  open my $file, '>:encoding(utf8)', $weight_file_name or die "$0: $weight_file_name: $!";
  print $file $self->{term_weight_vector}->stringify;
  close $file;
} # save_term_weight_vector

sub are_related_ids ($$$;$) {
  my ($self, $id1, $id2, $answer) = @_;
  
  my $w = $self->term_weight_vector;
  
  my $tfidf_db = $self->db->id_tfidf;

  ## TODO: cache
  
  require SWE::Data::FeatureVector;
  my $fv1 = SWE::Data::FeatureVector->parse_stringref
      ($tfidf_db->get_data ($id1));
  my $fv2 = SWE::Data::FeatureVector->parse_stringref
      ($tfidf_db->get_data ($id2));
  
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
