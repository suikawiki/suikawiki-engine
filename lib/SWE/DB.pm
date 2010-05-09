package SWE::DB;
use strict;
use warnings;

sub new ($) {
  my $self = bless {}, shift;
  return $self;
} # new

sub db_dir_name : lvalue { $_[0]->{db_dir_name} }
sub global_lock_dir_name : lvalue { $_[0]->{global_lock_dir_name} }
sub id_dir_name : lvalue { $_[0]->{id_dir_name} }
sub name_dir_name : lvalue { $_[0]->{name_dir_name} }

sub graph_dir_name ($) {
  my $self = shift;
  return $self->db_dir_name . q[graph/];
} # graph_dir_name

sub global_dir_name ($) {
  my $self = shift;
  return $self->db_dir_name . q[global/];
} # global_dir_name

sub sw3db_dir_name : lvalue { $_[0]->{sw3db_dir_name} }

sub global_prop ($) {
  my $self = shift;

  ## Lock types:
  ##   - Graph: lastnodeindex, doconnodenumber

  return $self->{global_prop} ||= do {
    require SWE::DB::NamedText;
    my $global_prop_db = SWE::DB::NamedText->new;
    $global_prop_db->{root_directory_name} = $self->global_dir_name;
    $global_prop_db->{leaf_suffix} = '.dat';
    $global_prop_db;
  };
} # global_prop

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

sub graph_prop ($) {
  my $self = shift;

  return $self->{graph_prop} ||= do {
    require SWE::DB::IDProps;
    my $graph_prop_db = SWE::DB::IDProps->new;
    $graph_prop_db->{root_directory_name} = $self->graph_dir_name;
    $graph_prop_db->{leaf_suffix} = '.node';
    $graph_prop_db;
  };
} # graph_prop

sub vc ($) {
  my $self = shift;

  require SWE::DB::VersionControl;
  return SWE::DB::VersionControl->new(db_dir_name => $self->{db_dir_name});
} # vc

1;
