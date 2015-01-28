package SWE::Object::Document;
use strict;
use warnings;
use SWE::String;
use SWE::Lang qw/%ContentMediaType/;

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

sub db ($) { $_[0]->{db} }

sub repo ($) { $_[0]->{repo} }

sub id ($) { $_[0]->{id} }

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
  eval qq{ require $module } or die $@;
  bless $self, $module;

  $self->reblessed = 1;
}

## ------ Metadata ------

sub prop ($) {
  my $self = shift;
  return $self->{prop} ||= do {
    $self->prop_untainted = 0 unless $self->locked;
    $self->db->id_prop->get_data ($self->id);
  };
} # prop

sub prop_untainted ($) : lvalue { $_[0]->{prop_untainted} }

sub untainted_prop ($) {
  my $self = shift;
  delete $self->{prop} unless $self->prop_untainted;
  $self->prop_untainted = 1;
  return $self->prop;
} # untainted_prop

sub save_prop ($) {
  my $self = shift;
  
  $self->lock;

  unless ($self->prop_untainted) {
    require Carp;
    die "Can't save a tainted prop object" . Carp::longmess ();
  }

  my $prop = $self->prop or die "Can't save an uncreated prop object";
  $self->db->id_prop->set_data ($self->id => $prop);
  
  $self->unlock;
} # save_prop

sub content_media_type ($) {
  my $self = shift;
  return $self->prop->{'content-type'} // 'text/x-suikawiki';
} # content_media_type

sub associate_names ($$%) {
  my ($self, $names, %args) = @_;

  ## NOTE: names_lock MUST be executed before the invocation.

  my $id = $self->id;
  my $time = $args{time} || time;

  my $vc = $self->db->vc;

  my $name_prop_db = $self->{name_prop_db}; ## TODO: ...
  local $name_prop_db->{version_control} = $vc;

  my $name_history_db = $self->db->name_history;
  local $name_history_db->{version_control} = $vc;
  
  for my $name (keys %$names) {
    my $name_props = $name_prop_db->get_data ($name);
    unless (defined $name_props) {
      $name_history_db->append_data ($name => [$time, 'c']);
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

  return $self->name;
} # title

sub name ($) {
  my $self = shift;

  my $prop = $self->prop;
  return [keys %{$prop->{name}}]->[0] // ''; ## XXXTODO: title-type
} # name

## ------ Indexing ------

sub update_tfidf ($$) {
return; # XXX

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
  for_unique_words {
    $orig_tfs->{$_[0]} = $_[1];
    $all_terms += $_[1];
  } $tc;

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

# ------ Locking ------

sub lock ($) {
  my $self = shift;
  my $lock = $self->{lock} ||= $self->db->id_lock->get_lock ($self->id);
  $self->{lock_n}++ or $lock->lock;
} # lock

sub unlock ($) {
  my $self = shift;
  my $lock = $self->{lock};
  $self->{lock_n}--;
  if ($lock and $self->{lock_n} <= 0) {
    $lock->unlock;
    delete $self->{lock};
    delete $self->{lock_n};
    delete $self->{prop_untainted};
  }
} # unlock

sub locked ($) {
  return (($_[0]->{lock_n} // 0) > 0);
} # locked

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
