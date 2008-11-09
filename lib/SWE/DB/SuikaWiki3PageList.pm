package SWE::DB::SuikaWiki3PageList;
use strict;

sub new ($) {
  my $self = bless {
    'file_name' => 'sw3pages.txt',
  }, shift;
  return $self;
} # new

sub _load_data ($) {
  my $self = shift;
  
  open my $file, '<:encoding(utf8)', $self->{file_name}
      or die "$0: $self->{file_name}: $!";
  while (<$file>) {
    tr/\x0D\x0A//d;
    my ($key, $label) = split / /, $_, 2;
    $self->{data}->{$label} = $key;
  }

  $self->{data_loaded} = 1;
} # _load_data

sub save_data ($) {
  my $self = shift;
  
  return unless $self->{data_loaded};
  
  open my $file, '>:encoding(utf8)', $self->{file_name}
      or die "$0: $self->{file_name}: $!";
  for (keys %{$self->{data} or {}}) {
    print $file "$self->{data}->{$_} $_\n";
  }
  close $file;
} # save_data

sub get_data ($$) {
  my ($self, $key) = @_;
  
  $self->_load_data unless $self->{data_loaded};

  return $self->{data}->{$key};
} # get_data

sub delete_data ($$) {
  my ($self, $key) = @_;
  
  $self->_load_data unless $self->{data_loaded};
  
  delete $self->{data}->{$key};
} # delete_data

sub reset ($) {
  my $self = shift;
  delete $self->{data_loaded};
  delete $self->{data};
} # reset

1;
