package SWE::DB::SuikaWiki3PageList2;
use strict;

require Digest::MD5;
require Encode;

sub new ($) {
  my $self = bless {
    root_directory_name => 'sw3pages/',
    leaf_suffix => '.txt',
  }, shift;
  return $self;
} # new

sub _get_file_name ($$$) {
  my $self = shift;
  my $hash = Digest::MD5::md5_hex (Encode::encode ('utf8', $_[0]));
  
  my $file_name = $self->{root_directory_name};
  $file_name .= substr ($hash, 0, 2);
  $file_name .= $self->{leaf_suffix};
  
  return $file_name;
} # _get_file_name

sub _load_data ($$) {
  my $self = shift;
  my $file_name = shift;

  if (-f $file_name) {
    open my $file, '<:encoding(utf8)', $file_name or die "$0: $file_name: $!";
    while (<$file>) {
      tr/\x0D\x0A//d;
      my ($key, $label) = split / /, $_, 2;
      $self->{data}->{$file_name}->{$label} = $key;
    }
  }
  
  $self->{data_loaded}->{$file_name} = 1;
} # _load_data

sub save_data ($) {
  my $self = shift;
  
  for my $file_name (keys %{$self->{data_loaded} or {}}) {
    next unless $self->{data_loaded}->{$file_name};

    open my $file, '>:encoding(utf8)', $file_name or die "$0: $file_name: $!";
    for (sort {$a cmp $b} keys %{$self->{data}->{$file_name} or {}}) {
      print $file "$self->{data}->{$file_name}->{$_} $_\n";
    }
    close $file;

    $self->{version_control}->add_file ($file_name)
        if $self->{version_control};
  }
} # save_data

sub get_data ($$) {
  my ($self, $key) = @_;

  my $file_name = $self->_get_file_name ($key);
  
  $self->_load_data ($file_name) unless $self->{data_loaded}->{$file_name};

  return $self->{data}->{$file_name}->{$key};
} # get_data

sub delete_data ($$) {
  my ($self, $key) = @_;

  my $file_name = $self->_get_file_name ($key);
  
  $self->_load_data ($file_name) unless $self->{data_loaded}->{$file_name};
  
  delete $self->{data}->{$file_name}->{$key};
} # delete_data

sub set_data ($$$) {
  my ($self, $key, $value) = @_;

  my $file_name = $self->_get_file_name ($key);
  
  $self->_load_data ($file_name) unless $self->{data_loaded}->{$file_name};

  $self->{data}->{$file_name}->{$key} = $value;
} # set_data

sub reset ($) {
  my $self = shift;
  delete $self->{data_loaded};
  delete $self->{data};
} # reset

1;
