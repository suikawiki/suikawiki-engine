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

require 'suikawiki/main.pl';
