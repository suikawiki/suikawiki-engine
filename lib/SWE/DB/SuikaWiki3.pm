package SWE::DB::SuikaWiki3;
use strict;

require Encode::EUCJPSW;

sub new ($) {
  my $self = bless {
    leaf_suffix => '.txt',
    root_directory_name => ',/',
  }, shift;
  return $self;
} # new

sub _get_file_name ($$) {
  my ($self, $key) = @_;
  
  return $self->{root_directory_name} . $key . $self->{leaf_suffix};
} # _get_file_name

sub get_data ($$) {
  my $self = $_[0];
  my $file_name = $self->_get_file_name ($_[1]);

  return undef unless -f $file_name;

  open my $file, '<:encoding(euc-jp-sw)', $file_name
      or die "$0: $file_name: $!";
  local $/ = undef;
  return scalar <$file>;
} # get_data

1;
