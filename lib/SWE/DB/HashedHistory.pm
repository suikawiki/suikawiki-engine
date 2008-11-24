package SWE::DB::HashedHistory;
use strict;

require SWE::DB::HashedProps;
push our @ISA, 'SWE::DB::HashedProps';

sub new ($) {
  my $self = shift->SUPER::new (@_);
  $self->{leaf_suffix} = '.history';
  return $self;
} # new

sub get_data ($$) {
  my $self = shift;
  my $file_name = $self->_get_file_name ($_[0]);

  unless (-f $file_name) {
    return undef;
  }

  my $r = [];

  open my $file, '<:encoding(utf8)', $file_name or die "$0: $file_name: $!";
  while (<$file>) {
    tr/\x0D\x0A//d;
    next unless length;
    my @v = split /\t/, $_, -1;
    push @$r, \@v;
  }
  
  return $r;
} # get_data

sub append_data ($$$) {
  my $self = shift;
  my $file_name = $self->_get_file_name (shift, 1);
  my $args = shift;
  s/[\x09-\x0D\x20]+/ /g for @$args;
  
  open my $file, '>>:encoding(utf8)', $file_name or die "$0: $file_name: $!";
  print $file join "\t", @$args;
  print $file "\n";
  close $file;

  $self->{version_control}->add_file ($file_name) if $self->{version_control};
} # append_data

1;
