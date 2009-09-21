package SWE::Object::Document;
use strict;
use warnings;
use SWE::Lang qw/%ContentMediaType/;
use UNIVERSAL::require;

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

sub reblessed : lvalue { $_[0]->{reblessed} }

sub rebless ($) {
  my $self = shift;
  return if $self->reblessed;

  my $id = $self->id;
  my $module;
  if (defined $id) {
    my $ct = $self->content_media_type;
    $module = $ContentMediaType{$ct}->{module} || $ContentMediaType{'text/x-suikawiki'}->{module};
  } else {
    $module = 'SWE::Object::Document::NotYet';
  }
  $module->require or die $@;
  bless $self, $module;

  $self->reblessed = 1;
}

## ------ Metadata ------

sub prop ($) {
  my $self = shift;
  return $self->{prop} ||= $self->db->id_prop->get_data ($self->id);
} # prop

sub content_media_type ($) {
  my $self = shift;
  return $self->prop->{'content-type'} // 'text/x-suikawiki';
} # content_media_type

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

sub title ($) {
  my $self = shift;

  my $prop = $self->prop;
  
  my $title = $prop->{title};
  return $title if defined $title and length $title;

  $title = [keys %{$prop->{name}}]->[0] // ''; ## XXXTODO: title-type
  return $title;
} # title

## ------ Indexing and Graph ------

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

sub get_or_create_graph_node ($) {
  my $self = shift;

  my $db = $self->db;
  my $doc_id = $self->id;

  my $id_prop = $db->id_prop->get_data ($doc_id);
  return undef unless $id_prop;

  require SWE::Object::Graph;
  my $graph = SWE::Object::Graph->new (db => $db);
  
  my $node;
  my $node_id = $id_prop->{node_id};
  if (defined $node_id) {
    $node = $graph->get_node_by_id ($node_id);
  } else {
    $node = $graph->create_node ($doc_id);
    $node_id = $node->id;
    
    $id_prop->{node_id} = $node_id;
    $db->id_prop->set_data ($doc_id => $id_prop);
  }

  return $node;
} # get_or_create_graph_node

# ------ Locking ------

sub lock ($) {
  my $self = shift;
  my $lock = $self->{lock} ||= $self->db->id_lock->get_lock ($self->id);
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

# ------ Format Convertion ------

sub to_text ($) {
  my $self = shift;

  return $self->{content_db}->get_data ($self->id); # XXX
} # to_text

sub to_text_media_type ($) {
  my $self = shift;
  return $self->content_media_type;
} # to_text_media_type

sub to_xml_media_type ($) {
  return undef;
} # to_xml_media_type

sub to_xml ($) {
  return undef;
} # to_xml

sub to_html_fragment ($) {
  return (undef, undef);
} # to_html_fragment

1;
