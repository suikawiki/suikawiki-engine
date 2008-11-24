#!/usr/bin/perl
use strict;

use lib qw[/home/httpd/html/www/markup/html/whatpm
           /home/wakaba/work/manakai2/lib
           /home/httpd/html/www/charclass/lib
           /home/httpd/html/swe/lib/];

use CGI::Carp qw[fatalsToBrowser];
require Message::CGI::Carp;

our $homepage_name = 'HomePage';
our $license_name = 'Wiki//Page//License';
our $style_url = q<http://suika.fam.cx/swe/styles/sw>;
our $script_url = q<http://suika.fam.cx/swe/scripts/sw>;
our $cvs_archives_url = q</gate/cvs/suikawiki/sw4data/>;

our $sw3_db_dir_name = q[/home/wakaba/public_html/-temp/wiki/wikidata/page/];
our $db_dir_name = 'data/';

require 'suikawiki/main.pl';
