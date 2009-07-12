package SWE::Object::Document;
use strict;
use warnings;

sub new ($%) {
  my $class = shift;
  my $self = bless {@_}, $class;

  return $self;
}

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

1;
