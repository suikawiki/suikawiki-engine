package SWE::DB::SuikaWiki3;
use strict;

require Encode::EUCJP1997;

sub new ($) {
  my $self = bless {
    ns_suffix => '.ns',
    leaf_suffix => '.txt',
    root_key => ['HomePage'],
    root_directory_name => ',/',
  }, shift;

  return $self;
} # new

my $get_file_name = sub {
  my $self = shift;
  my $key = shift;
  $key = $self->{root_key} if @$key == 0;

  my $file_name = $self->{root_directory_name};
  $file_name .= join '/',
      map { s/(.)/sprintf '%02X', ord $1/sge; $_ . $self->{ns_suffix} } 
      map { Encode::encode ('euc-jp-1997', $_) } @$key;
  $file_name =~ s/\Q$self->{ns_suffix}\E$/$self->{leaf_suffix}/;
  
  return $file_name;
}; # $get_file_name

sub get_data ($$) {
  my $self = shift;
  my $file_name = $get_file_name->($self, $_[0]);

  return undef unless -f $file_name;

  open my $file, '<:encoding(euc-jp-1997)', $file_name
      or die "$0: $file_name: $!";
  local $/ = undef;
  return scalar <$file>;
} # get_data

sub set_data ($$$) {

## not implemented yet.

} # set_data

1;
