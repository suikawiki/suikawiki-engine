package SWE::DB::SuikaWiki3LastModified;
use strict;

require Encode::EUCJPSW;

sub new ($) {
  my $self = bless {
    file_name => 'lastmodified.dat',
  }, shift;
} # new

sub _load_data ($) {
  my $self = shift;

  open my $file, '<', $self->{file_name} or die "$0: $self->{file_name}: $!";
  local $/ = undef;
  my $val = <$file>;
  close $file;

  if ($val =~ s!^\#\?SuikaWikiMetaInfo/0.9[^\x02]*\x02!!s) {
    $self->{data} = {map {(Encode::decode ('euc-jp-sw', $_->[0]), $_->[1])}
                     map {[split /\x1F/, $_, 2]} split /\x1E/, $val};
  }

  $self->{data_loaded} = 1;
} # _load_data

sub get_data ($$) {
  my ($self, $page_name) = @_;
  $self->_load_data unless $self->{data_loaded};
  
#  $page_name =~ s/ /\x2F\x2F/g;
  return $self->{data}->{$page_name};
} # get_data

1;
