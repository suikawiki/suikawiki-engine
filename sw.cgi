#!/usr/bin/perl
use strict;

use lib qw[/home/httpd/html/www/markup/html/whatpm
           /home/wakaba/work/manakai2/lib
           /home/httpd/html/www/charclass/lib
           /home/httpd/html/swe/lib/];

use CGI::Carp qw[fatalsToBrowser];
require Message::CGI::Carp;

our $homepage_name = 'HomePage';
our $license_name = 'WikiPageLicense';
our $help_page_name = 'HelpPage';

our $style_url = q<http://suika.fam.cx/swe/styles/sw>;
our $script_url = q<http://suika.fam.cx/swe/scripts/sw>;
our $cvs_archives_url = q</gate/cvs/suikawiki/sw4data/>;

our $sw3_db_dir_name = q[/home/wakaba/public_html/-temp/wiki/wikidata/page/];
our $db_dir_name = 'data/';

my $log_file_name = 'data/all.tmp';
my $time1 = time;
#open my $log_file, '>>', $log_file_name;
#print $log_file "S: ", scalar gmtime, "\t", $ENV{REQUEST_URI}, "\n";
#close $log_file;
END {
my $time2 = time - $time1;
open my $log_file, '>>', $log_file_name;
print $log_file "$time2\tE: $$ ", scalar gmtime, "\t$ENV{REQUEST_METHOD} $ENV{CONTENT_LENGTH}\t", $ENV{REQUEST_URI}, "\n";
}

require 'suikawiki/main.pl';
