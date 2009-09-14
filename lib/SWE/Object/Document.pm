package SWE::Object::Document;
use strict;
use warnings;

sub new ($%) {
  my $class = shift;
  my $self = bless {@_}, $class;

  return $self;
}

sub new_id ($%) {
  my $self = shift->new (@_);
  
  ## NOTE: MUST be executed in names_lock.

  my $idgen = $self->db->id;
  my $id = $idgen->get_next_id;
  $self->{id} = $id;

  return $self;
} # new_id

sub db { $_[0]->{db} }

sub id { $_[0]->{id} }

sub associate_names ($$%) {
  my ($self, $names, %args) = @_;

  ## NOTE: names_lock MUST be executed before the invocation.

  my $id = $self->id;
  my $time = $args{time} || time;
  my $sw3_pages = $self->{sw3_pages}; ## TODO: ...

  my $vc = $self->db->vc;

  my $name_prop_db = $self->{name_prop_db}; ## TODO: ...
  local $name_prop_db->{version_control} = $vc;

  my $name_history_db = $self->db->name_history;
  local $name_history_db->{version_control} = $vc;
  
  for my $name (keys %$names) {
    my $name_props = $name_prop_db->get_data ($name);
    unless (defined $name_props) {
      my $sw3id = $sw3_pages->get_data ($name);
      main::convert_sw3_page ($sw3id => $name); ## TODO: ...
      
      $name_props = $name_prop_db->get_data ($name);
      unless (defined $name_props) {
        $name_history_db->append_data ($name => [$time, 'c']);
      }
    }
    
    push @{$name_props->{id} ||= []}, $id;
    $name_props->{name} = $name;
    $name_prop_db->set_data ($name => $name_props);
    
    $name_history_db->append_data ($name => [$time, 'a', $id]);
  }

  my $user = $args{user} || '(anon)';
  $vc->commit_changes ("id=$id created by $user");
} # associate_names

sub update_tfidf ($$) {
  my ($self, $doc) = @_; ## TODO: $doc should not be an argument

  ## It is REQUIRED to lock the $id before the invocation of this
  ## method to keep the consistency of tfidf data for the $id.

  my $id = $self->id;

  my $tfidf_db = $self->db->id_tfidf;

  require SWE::Data::FeatureVector;

  my $deleted_terms = SWE::Data::FeatureVector->parse_stringref
      ($tfidf_db->get_data ($id))->as_key_hashref;

  my $tc = $doc->document_element->text_content;

  ## TODO: use element semantics...

  my $orig_tfs = {};
  my $all_terms = 0;
  main::for_unique_words ($tc => sub {
    $orig_tfs->{$_[0]} = $_[1];
    $all_terms += $_[1];
  }); ## TODO: XXX

  my $names_index_db = $self->db->name_inverted_index;
  $names_index_db->lock;

  my $idgen = $self->db->id;
  my $doc_number = $idgen->get_last_id;
  
  my $terms = SWE::Data::FeatureVector->new;
  for my $term (keys %$orig_tfs) {
    my $n_tf = $orig_tfs->{$term} / $all_terms;
    
    my $df = $names_index_db->get_count ($term);
    my $idf = log ($doc_number / ($df + 1));
      
    my $tfidf = $n_tf * $idf;
    
    $terms->set_tfidf ($term, $tfidf);
    $names_index_db->add_data ($term => $id => $tfidf);

    delete $deleted_terms->{$term};
  }

  for my $term (keys %$deleted_terms) {
    $names_index_db->delete_data ($term, $id);
  }
  
  $tfidf_db->set_data ($id => \( $terms->stringify ));
} # update_tfidf

sub to_text ($) {
  my $self = shift;

  return $self->{content_db}->get_data ($self->id); # XXX
} # to_text

sub to_text_media_type ($) {
  my $self = shift;
  my $id_prop = $self->{id_prop_db}->get_data ($self->id); ## XXX
  return $id_prop->{'content-type'} // 'text/x-suikawiki';
} # to_text_media_type

sub lock ($) {
  my $self = shift;
  my $lock = $self->{lock} ||= $self->{id_locks}->get_lock ($self->id); ## XXX
  $self->{lock_n}++ or $self->lock;
} # lock

sub unlock ($) {
  my $self = shift;
  my $lock = $self->{lock};
  $self->{lock_n}--;
  if ($lock and $self->{lock_n} <= 0) {
    $lock->unlock;
    delete $self->{lock};
    delete $self->{lock_n};
  }
} # unlock

sub to_xml ($;%) {
  my ($self, %args) = @_;

  my $id = $self->id;

  $self->lock;
  
  my $id_prop = $self->{id_prop_db}->get_data ($id); ## XXX
  my $cache_prop = $self->{cache_prop_db}->get_data ($id); ## XXX
  my $doc = $self->{swml_to_xml}->($id, $id_prop, $cache_prop); ## XXX

  $self->unlock;

  if ($args{styled}) {
    my $pi = $doc->create_processing_instruction
        ('xml-stylesheet', 'href="http://suika.fam.cx/www/style/swml/structure"');
    $doc->insert_before ($pi, $doc->first_child);
  }
  
  return $doc;
}

sub to_xml_media_type ($) {
  return 'application/xml';
}

1;
