package SWE::DB::IDProps;
use strict;

sub new ($) {
  my $self = bless {
    root_directory_name => './',
    leaf_suffix => '.props',
  }, shift;
  return $self;
} # new

sub _get_file_name ($$$) {
  my $self = shift;
  my $id = $_[0] + 0;
  my $mkdir = $_[1];
  
  my $dir = $self->{root_directory_name} . int ($id / 1000);
  my $file_name = $dir . '/' . ($id % 1000) . $self->{leaf_suffix};

  unless ($mkdir) {
    return $file_name;
  }
  
  unless (-d $dir) {
    mkdir $dir or die "$0: $dir: $!";
  }

  unless (-d $dir . '/CVS') {
    ## TODO: ...
  }

  return $file_name;
} # _get_file_name

sub get_data ($$) {
  my $self = shift;
  my $file_name = $self->_get_file_name ($_[0]);
  
  unless (-f $file_name) {
    return {};
  }
  
  my $r = {};
  
  open my $file, '<:encoding(utf8)', $file_name or die "$0: $file_name: $!";
  while (<$file>) {
    tr/\x0D\x0A//d;
    my ($n, $v) = split /:/, $_, 2;
    if ($n =~ s/^\@//) {
      push @{$r->{$n} ||= []}, $v // '';
    } elsif ($n =~ s/^%//) {
      $r->{$n}->{$v // ''} = 1;
    } else {
      $n =~ s/^\$//;
      $r->{$n} = $v // '';
    }
  }
  
  return $r;
} # get_data

sub set_data ($$$) {
  my $self = shift;
  my $file_name = $self->_get_file_name ($_[0], 1);
  my $prop = $_[1];
  
  my $has_file = -f $file_name;

  open my $file, '>:encoding(utf8)', $file_name or die "$0: $file_name: $!";
  for my $prop_name (sort {$a cmp $b} keys %$prop) {
    if (ref $prop->{$prop_name} eq 'ARRAY') {
      my $v = '@' . $prop_name;
      $v =~ tr/\x0D\x0A://d;
      for (@{$prop->{$prop_name}}) {
        my $pv = $_;
        $pv =~ tr/\x0D\x0A/  /;
        print $file $v . ':' . $pv . "\x0A";
      }
    } elsif (ref $prop->{$prop_name} eq 'HASH') {
      my $v = '%' . $prop_name;
      $v =~ tr/\x0D\x0A://d;
      for (sort {$a cmp $b} keys %{$prop->{$prop_name}}) {
        next unless $prop->{$prop_name}->{$_};
        my $pv = $_;
        $pv =~ tr/\x0D\x0A/  /;
        print $file $v . ':' . $pv . "\x0A";
      }
    } else {
      my $v = '$' . $prop_name;
      $v =~ tr/\x0D\x0A://d;
      my $pv = $prop->{$prop_name};
      $pv =~ tr/\x0D\x0A/  /;
      print $file $v . ':' . $pv . "\x0A";
    }
  }
  close $file;

## TODO:
#  system_ ('cvs', 'add', $file_name) unless $has_file;
} # set_data

1;
