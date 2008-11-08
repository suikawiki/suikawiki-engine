package SWE::DB::SuikaWiki3LastModified;
use strict;

require Encode::EUCJPSW;

sub new ($) {
  my $self = bless {
    file_name => 'lastmodified.dat',
    root_key => ['HomePage'],
  }, shift;
} # new

sub load_data ($) {
  my $self = shift;

  open my $file, '<', $self->{file_name} or die "$0: $self->{file_name}: $!";
  local $/ = undef;
  my $val = <$file>;
  close $file;

  if ($val =~ s!^\#\?SuikaWikiMetaInfo/0.9[^\x02]*\x02!!s) {
    $self->{data} = {map {(Encode::decode ('euc-jp-sw', $_->[0]), $_->[1])}
                     map {[split /\x1F/, $_, 2]} split /\x1E/, $val};
  }
} # load_data

sub save_data ($) {
  my $self = shift;

  open my $file, '>', $self->{file_name} or die "$0: $self->{file_name}: $!";

  print $file "#?SuikaWikiMetaInfo/0.9\n\x02"
            .join "\x1E",
             map {
               my ($n, $v) = (Encode::encode ('euc-jp-sw', $_), $self->{data}->{$_});
               for ($n, $v) {s/([\x02\x1C-\x1F])/sprintf '\\x%02X', ord $1/ge}
               $n."\x1F".$v;
             }
             grep {length $self->{data}->{$_}}
             keys %{$self->{data} or {}};
} # save_data

sub get_data ($$) {
  my ($self, $key) = @_;
  $key = $self->{root_key} unless @$key;
  
  return $self->{data}->{join '//', @$key};
} # get_data

sub set_data ($$$) {
  my ($self, $key, $value) = @_;
  $key = $self->{root_key} unless @$key;
  
  $self->{data}->{join '//', @$key} = $value;
} # set_data

1;
