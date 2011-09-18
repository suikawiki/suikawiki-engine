package SuikaWiki5::Main;
use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('modules', '*', 'lib');

BEGIN {
  my $env = $ENV{X_SW_ENV} || 'wiki';

  my $config_f = file (__FILE__)->dir->parent->parent->subdir ('config')->file ($env . '.pl');
  require ($config_f->stringify);
}

sub handler {
  if ($ENV{X_SW_USE_QUERY_STRING_AS_URL}) {
    my $url = $ENV{QUERY_STRING};
    if (defined $url and length $url) {
      $url =~ s/\#.*$//s;
      $ENV{REQUEST_URI} = $url;
      if ($url =~ s/\?(.*)$//s) {
        $ENV{QUERY_STRING} = $1;
      } else {
        delete $ENV{QUERY_STRING};
      }
    }
  }

  require 'suikawiki/main.pl';

  eval {
    SuikaWiki5::Main->main;
    1;
  } or do {
    print "Status: 500 Internal WikiEngine Error\n";
    print "Content-Type: text/plain; charset=utf-8\n";
    print "\n";
    print "500 Internal WikiEngine Error\n\n";
    print $@;
  };

  return 0;
}

1;
