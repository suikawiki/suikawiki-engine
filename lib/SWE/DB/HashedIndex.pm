package SWE::DB::HashedIndex;
use strict;

sub new ($) {
  my $self = bless {
    root_directory_name => './',
    directory_suffix => '.hi',
    id_directory_suffix => '.id',
    leaf_suffix => '.x',
  }, shift;
  return $self;
} # new

require Digest::MD5;
require Encode;

sub _get_file_name ($$$$) {
  my $self = shift;
  my $hash = Digest::MD5::md5_hex (Encode::encode ('utf8', $_[0]));
  my $mkdir = $_[1];
  my $id = $_[2];
  
  my $dir1 = $self->{root_directory_name} . substr ($hash, 0, 2);
  my $dir2 = $dir1 . '/' . substr ($hash, 2, 2);
  substr ($hash, 0, 4) = '';
  my $dir3 = $dir2 . '/' . $hash . $self->{directory_suffix};
  my $dir4;

  my $file_name = $dir3;

  if (defined $id) {
    $dir4 = $dir3 . '/' . int ($id / 1000) . $self->{id_directory_suffix};
    $file_name = $dir4 . '/' . ($id % 1000) . $self->{leaf_suffix};
  }

  unless ($mkdir) {
    return $file_name;
  }
  
  unless (-d $dir1) {
    mkdir $dir1 or die "$0: $dir1: $!";
  }

  unless (-d $dir2) {
    mkdir $dir2 or die "$0: $dir2: $!";
  }

  unless (-d $dir3) {
    mkdir $dir3 or die "$0: $dir3: $!";
  }

  if (defined $dir4 and not -d $dir4) {
    mkdir $dir4 or die "$0: $dir4: $!";
  }

  if ($self->{version_control}) {
    $self->{version_control}->add_directory ($dir1);
    $self->{version_control}->add_directory ($dir2);
    $self->{version_control}->add_directory ($dir3);
    $self->{version_control}->add_directory ($dir4) if defined $dir4;
  }

  return $file_name;
} # _get_file_name

sub _for_each_id ($$$) {
  my $self = shift;
  my $dir_name = $self->_get_file_name ($_[0]);
  
  unless (-d $dir_name) {
    return;
  }
  
  my $code = $_[1];

  opendir my $d, $dir_name or die "$0: $dir_name: $!";
  while (defined (my $id_dir_name = readdir $d)) {
    next unless substr ($id_dir_name, -length $self->{id_directory_suffix})
        eq $self->{id_directory_suffix};
   
    my $id_high = 0+substr $id_dir_name,
        0, length $id_dir_name - length $self->{id_directory_suffix};
    my $id_directory_name = $dir_name . '/' . $id_dir_name;
    opendir my $dd, $id_directory_name or die "$0: $id_directory_name: $!";
    while (defined (my $f_name = readdir $dd)) {
      next unless substr ($f_name, -length $self->{leaf_suffix})
          eq $self->{leaf_suffix};
      
      my $id = $id_high * 1000 +
          substr $f_name, 0, length $f_name - length $self->{leaf_suffix};
      my $file_name = $id_directory_name . '/' . $f_name;
      $code->($id, $file_name);
    }
    close $dd;
  }
  close $d;
} # _for_each_id

sub get_data ($$) {
  my $self = shift;

  my $r = {};
  local $/ = undef;

  $self->_for_each_id ($_[0], sub ($$) {
    my ($id, $id_file_name) = @_;
    
    open my $file, '<:encoding(utf8)', $id_file_name
        or die "$0: $id_file_name: $!";
    $r->{$id} = <$file>;
    close $file;
  });

  return $r;
} # get_data

sub get_count ($$) {
  my $self = shift;

  my $r = 0;

  $self->_for_each_id ($_[0], sub {
    $r++;
  });

  return $r;
} # get_count

sub add_data ($$$;$) {
  my $self = shift;
  my $file_name = $self->_get_file_name ($_[0], 1, $_[1]);
  my $value = $_[2] // '';
  
  open my $file, '>:encoding(utf8)', $file_name or die "$0: $file_name: $!";
  print $file $value;
  close $file;
  
  $self->{version_control}->add_file ($file_name) if $self->{version_control};
} # add_data

sub delete_data ($$$) {
  my $self = shift;
  my $file_name = $self->_get_file_name ($_[0], 0, $_[1]);

  unlink $file_name or die "$0: $file_name: $!" if -f $file_name;
  
  $self->{version_control}->remove_file ($file_name) if $self->{version_control};
} # delete_data

1;
