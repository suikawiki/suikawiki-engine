package SWE::DB;
use strict;
use warnings;

sub new_from_root_path ($$) {
  my $self = bless {root_path => $_[1]}, $_[0];
  ($self->{ids_path} = $self->{root_path}->child ('ids'))->mkpath;
  ($self->{names_path} = $self->{root_path}->child ('names'))->mkpath;
  return $self;
} # new

sub root_path ($) {
  return $_[0]->{root_path};
} # root_path

## DEPRECATED
sub db_dir_name ($) {
  return $_[0]->{root_path} . '/';
} # db_dir_name

## DEPRECATED
sub global_lock_dir_name ($) {
  return $_[0]->db_dir_name;
} # global_lock_dir_name

## DEPRECATED
sub id_dir_name ($) {
  return $_[0]->{ids_path} . '/';
} # id_dir_name

## DEPRECATED
sub name_dir_name ($) {
  return $_[0]->{names_path} . '/';
} # name_dir_name

## NOTE: This lock MUST be used when $db->name_prop is updated.
sub names_lock ($) {
  my $self = shift;
  return $self->{names_lock} ||= do {
    require SWE::DB::Lock;
    my $names_lock = SWE::DB::Lock->new;
    $names_lock->{file_name} = $self->global_lock_dir_name . 'ids.lock';
    $names_lock->lock_type ('Names');
    $names_lock;
  };
} # names_lock

sub name_inverted_index ($) {
  my $self = shift;
  
  return $self->{name_inverted_index} ||= do {
    require SWE::DB::HashedIndex;
    my $names_index_db = SWE::DB::HashedIndex->new;
    $names_index_db->{root_directory_name} = $self->name_dir_name;
    $names_index_db;
  };
} # name_inverted_index

sub name_history ($) {
  my $self = shift;
  return $self->{name_history} ||= do {
    require SWE::DB::HashedHistory;
    my $names_history_db = SWE::DB::HashedHistory->new;
    $names_history_db->{root_directory_name} = $self->name_dir_name;
    $names_history_db;
  };
} # name_history

sub name_prop ($) {
  my $self = shift;
  return $self->{name_prop} ||= do {
    require SWE::DB::HashedProps;
    my $name_prop_db = SWE::DB::HashedProps->new;
    $name_prop_db->{root_directory_name} = $self->name_dir_name;
    $name_prop_db->{leaf_suffix} = '.props';
    $name_prop_db;
  };
} # name_prop

sub id ($) {
  my $self = shift;
  
  return $self->{id} ||= do {
    require SWE::DB::IDGenerator;
    my $idgen = SWE::DB::IDGenerator->new;
    $idgen->{file_name} = $self->db_dir_name . 'nextid.dat';
    $idgen->{lock_file_name} = $self->global_lock_dir_name . 'nextid.lock';
    $idgen;
  };
} # id

sub id_lock ($) {
  my $self = shift;
  return $self->{id_lock} ||= do {
    require SWE::DB::IDLocks;
    my $id_locks = SWE::DB::IDLocks->new;
    $id_locks->{root_directory_name} = $self->id_dir_name;
    $id_locks->{leaf_suffix} = '.lock';
    $id_locks;
  };
} # id_lock

sub id_content ($) {
  my $self = shift;
  return $self->{id_content} ||= do {
    require SWE::DB::IDText;
    my $id_content_db = SWE::DB::IDText->new;
    $id_content_db->{root_directory_name} = $self->id_dir_name;
    $id_content_db->{leaf_suffix} = '.txt';
    $id_content_db;
  };
} # id_content

sub id_prop ($) {
  my $self = shift;
  return $self->{id_prop} ||= do {
    require SWE::DB::IDProps;
    my $id_prop_db = SWE::DB::IDProps->new;
    $id_prop_db->{root_directory_name} = $self->id_dir_name;
    $id_prop_db->{leaf_suffix} = '.props';
    $id_prop_db;
  };
} # id_prop

sub id_tfidf ($) {
  my $self = shift;
  return $self->{id_tfidf} ||= do {
    require SWE::DB::IDText;
    my $tfidf_db = SWE::DB::IDText->new;
    $tfidf_db->{root_directory_name} = $self->id_dir_name;
    $tfidf_db->{leaf_suffix} = '.tfidf';
    $tfidf_db;
  };
} # id_tfidf

sub id_history ($) {
  my $self = shift;
  return $self->{id_history} ||= do {
    require SWE::DB::IDHistory;
    my $id_history_db = SWE::DB::IDHistory->new;
    $id_history_db->{root_directory_name} = $self->id_dir_name;
    $id_history_db;
  };
} # id_history

sub id_dom_cache ($) {
  my $self = shift;
  return $self->{id_dom_cache} ||= do {
    require SWE::DB::IDDOM;
    my $dom_cache_db = SWE::DB::IDDOM->new;
    $dom_cache_db->{root_directory_name} = $self->id_dir_name;
    $dom_cache_db->{leaf_suffix} = '.domcache';
    $dom_cache_db;
  };
} # id_dom_cache

sub id_html_cache ($) {
  my $self = shift;
  return $self->{id_html_cache} ||= do {
    require SWE::DB::IDDOM;
    my $html_cache_db = SWE::DB::IDDOM->new;
    $html_cache_db->{root_directory_name} = $self->id_dir_name;
    $html_cache_db->{leaf_suffix} = '.htmlcache';
    $html_cache_db;
  };
} # id_html_cache

sub id_cache_prop ($) {
  my $self = shift;
  return $self->{id_cache_prop} ||= do {
    require SWE::DB::IDProps;
    my $id_cache_prop_db = SWE::DB::IDProps->new;
    $id_cache_prop_db->{root_directory_name} = $self->id_dir_name;
    $id_cache_prop_db->{leaf_suffix} = '.cacheprops';
    $id_cache_prop_db;
  };
} # id_cache_prop

sub id_data_history ($) {
  my $self = $_[0];
  return $self->{id_data_history} ||= do {
    require SWE::DB::IDDataHistory;
    SWE::DB::IDDataHistory->new_from_root_path ($self->root_path);
  };
} # id_data_history

sub vc ($) {
  my $self = shift;
  require SWE::DB::VersionControl;
  return SWE::DB::VersionControl->new (db_dir_name => $self->db_dir_name);
} # vc

1;
