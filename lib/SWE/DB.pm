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

sub sw3db_dir_name : lvalue { $_[0]->{sw3db_dir_name} }

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

sub name_inverted_index ($) {
  my $self = shift;
  
  return $self->{name_inverted_index} ||= do {
    require SWE::DB::HashedIndex;
    my $names_index_db = SWE::DB::HashedIndex->new;
    $names_index_db->{root_directory_name} = $self->name_dir_name;
    $names_index_db;
  };
} # name_inverted_index

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

1;
