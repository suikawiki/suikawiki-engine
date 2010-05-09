#!/usr/bin/perl
use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules/*/lib');

use CGI::Carp qw[fatalsToBrowser];
require Message::CGI::Carp;

our $homepage_name = 'HomePage';
our $license_name = 'WikiPageLicense';
our $help_page_name = 'HelpPage';

our $style_url = q<http://suika.fam.cx/swe/styles/sw>;
our $script_url = q<http://suika.fam.cx/swe/scripts/sw>;
our $cvs_archives_url = q</gate/cvs/melon/pub/suikawiki/sw4data/>;

our $sw3_db_dir_name = q[/home/wakaba/server/sw3/wikidata/page/];
our $db_dir_name = q[/data1/sw/sw4data/];

my $log_file_name = '/data1/sw/sw4data/all.tmp';
my $time1 = time;
#open my $log_file, '>>', $log_file_name;
#print $log_file "S: ", scalar gmtime, "\t", $ENV{REQUEST_URI}, "\n";
#close $log_file;
END {
my $time2 = time - $time1;
open my $log_file, '>>', $log_file_name or do { warn "$0: $log_file_name: $!"; return };
print $log_file "$time2\tE: $$ ", scalar gmtime, "\t$ENV{REQUEST_METHOD} $ENV{CONTENT_LENGTH}\t", $ENV{REQUEST_URI}, "\n";
}

require 'suikawiki/main.pl';
