package SWE::DB::NamedText;
use strict;

sub new ($) {
  my $self = bless {
    root_directory_name => './',
    leaf_suffix => '.txt',
  }, shift;
  return $self;
} # new

sub _get_file_name ($$$) {
  my $self = shift;
  my $name = $_[0];
  my $mkdir = $_[1];
  
  my $encoded_name = $name;
  $encoded_name =~ s/([^0-9A-Za-z_-])/sprintf '@%06X', ord $1/ge;

  my $dir = $self->{root_directory_name};
  my $file_name = $dir . '/' . $encoded_name . $self->{leaf_suffix};

  unless ($mkdir) {
    return $file_name;
  }
  
  unless (-d $dir) {
    mkdir $dir or die "$0: $dir: $!";
  }

  $self->{version_control}->add_directory ($dir) if $self->{version_control};

  return $file_name;
} # _get_file_name

sub get_data ($$) {
  my $self = shift;
  my $file_name = $self->_get_file_name ($_[0]);

  unless (-f $file_name) {
    return undef;
  }

  open my $file, '<:encoding(utf8)', $file_name or die "$0: $file_name: $!";
  local $/ = undef;
  return \ (<$file>);
} # get_data

sub set_data ($$$) {
  my $self = shift;
  my $file_name = $self->_get_file_name ($_[0], 1);
  my $textref = $_[1];
  
  open my $file, '>:encoding(utf8)', $file_name or die "$0: $file_name: $!";
  print $file $$textref;
  close $file;

  $self->{version_control}->add_file ($file_name) if $self->{version_control};
} # set_data

1;
