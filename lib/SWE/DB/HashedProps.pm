package SWE::DB::HashedProps;
use strict;

require SWE::DB::IDProps;
push our @ISA, 'SWE::DB::IDProps';

require Digest::MD5;
require Encode;

sub _get_file_name ($$$) {
  my $self = shift;
  my $hash = Digest::MD5::md5_hex (Encode::encode ('utf8', $_[0]));
  my $mkdir = $_[1];
  
  my $dir1 = $self->{root_directory_name} . substr ($hash, 0, 2);
  my $dir2 = $dir1 . '/' . substr ($hash, 2, 2);
  substr ($hash, 0, 4) = '';

  my $file_name = $dir2 . '/' . $hash . $self->{leaf_suffix};

  unless ($mkdir) {
    return $file_name;
  }
  
  unless (-d $dir1) {
    mkdir $dir1 or die "$0: $dir1: $!";
  }

  unless (-d $dir1 . '/CVS') {
    ## TODO: ...
  }

  unless (-d $dir2) {
    mkdir $dir2 or die "$0: $dir2: $!";
  }

  unless (-d $dir2 . '/CVS') {
    ## TODO: ...
  }

  return $file_name;
} # _get_file_name

1;
