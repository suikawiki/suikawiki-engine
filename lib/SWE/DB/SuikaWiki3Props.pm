package SWE::DB::SuikaWiki3Props;
use strict;
require SWE::DB::SuikaWiki3;
push our @ISA, 'SWE::DB::SuikaWiki3';

require Encode::EUCJPSW;

sub new ($) {
  my $self = shift->SUPER::new (@_);
  $self->{leaf_suffix} = '.prop';
  return $self;
} # new

sub get_data ($$) {
  my $self = shift;
  my $data = $self->SUPER::get_data (@_);

  return {} unless defined $data;
 
  my $prop_name = {
q<http://suika.fam.cx/~wakaba/-temp/2004/04/24/mt#media-type> => 'content-type',
q<http://suika.fam.cx/~wakaba/archive/2004/8/11/sw-bt#creation-date> => 'created',
q<http://suika.fam.cx/~wakaba/archive/2004/7/25/html-relrev#up> => '%rel-up',
q<http://suika.fam.cx/~wakaba/archive/2004/7/25/html-relrev#down> => '%rev-up',
q<http://suika.fam.cx/~wakaba/archive/2004/7/25/html-relrev#next> => '%rel-next',
q<http://suika.fam.cx/~wakaba/archive/2004/7/25/html-relrev#prev> => '%rel-prev',
q<http://suika.fam.cx/~wakaba/archive/2004/8/11/sw-bt#category> => '%rel-tag',
q<http://suika.fam.cx/~wakaba/archive/2004/7/20/sw-propedit#inCategory> => '%rev-tag',
q<http://suika.fam.cx/~wakaba/archive/2004/7/20/sw#category> => '%rel-tag',
q<http://suika.fam.cx/~wakaba/archive/2004/7/20/sw#keyword> => '%rel-tag',
q<http://suika.fam.cx/~wakaba/archive/2004/7/25/html-relrev#index> => '%rel-index',
q<http://suika.fam.cx/~wakaba/archive/2004/7/25/html-relrev#contents> => '%rel-index',
q<http://suika.fam.cx/~wakaba/-temp/wiki/wiki?SuikaWiki%2F0.9#page-icon> => '%rel-icon',
q<http://suika.fam.cx/~wakaba/archive/2004/7/20/sw#obsolete> => '%obsoleted-by',
q<http://suika.fam.cx/~wakaba/archive/2004/7/20/sw#license> => 'rights',
q<http://suika.fam.cx/~wakaba/archive/2004/7/20/sw#license--type> => 'rights-type',
q<http://suika.fam.cx/~wakaba/archive/2004/8/11/sw-bt#subject> => 'title',
q<http://suika.fam.cx/~wakaba/archive/2004/7/20/sw#abstract> => 'summary',
q<http://suika.fam.cx/~wakaba/archive/2004/7/20/sw#abstract--type> => 'summary-type',
q<http://suika.fam.cx/~wakaba/archive/2004/8/11/sw-bt#status> => 'bug-status',
q<http://suika.fam.cx/~wakaba/archive/2004/8/11/sw-bt#priority> => 'bug-priority',
q<http://suika.fam.cx/~wakaba/archive/2004/7/20/sw-propedit#seq> => 'prop-revision',
  };
  my $last_prop = '';
  my $r = {};
  for (split /\x0D\x0A?|\x0A/, $data) {
    if (s/^\s+//) {
      s/^\\//;
      if ($last_prop =~ /^%/) {
        $r->{$last_prop}->{$_} = 1;
      } elsif (defined $r->{$last_prop}) {
        $r->{$last_prop} = "\x0A" . $_;
      } else {
        $r->{$last_prop} = $_;
      }
    } else {
      my $prop = $_;
      my $value;
      if ($prop =~ s/:([^:]*)\z//) {
        $value = $1;
        $value =~ s/^\s+//;
        undef $value unless length $value;
      } else {
        $prop =~ s/:\s*\z//;
      }
      $prop =~ s/\[list\]$//;

      my $pn = $prop_name->{$prop} // $prop;
      $last_prop = $pn;

      if (defined $value) {
        if ($pn =~ /^%/) {
          $r->{$pn}->{$value} = 1;
        } elsif (defined $r->{$pn}) {
          $r->{$pn} .= "\x0A" . $value;
        } else {
          $r->{$pn} = $value;
        }
      }
    }
  }

  for my $prop (qw/content-type summary-type rights-type/) {
    if (defined $r->{$prop}) {
      $r->{$prop} = {
                     'IMT:text/x.suikawiki.image;version="0.9"##' => 'text/x.suikawiki.image',
                     'IMT:text/x-suikawiki;version="0.10"##' => 'text/x-suikawiki',
                     'IMT:text/x-suikawiki;version="0.9"##' => 'text/x-suikawiki',
                     'IMT:application/x.suikawiki.config;version="2.0"##' => 'application/x.suikawiki.config',
                     'IMT:text/plain##' => 'text/plain',
                     'IMT:text/css##' => 'text/css',
                    }->{$r->{$prop}} // $r->{$prop};
    }
  }

  return $r;
} # get_data

1;
