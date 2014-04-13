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

1;
