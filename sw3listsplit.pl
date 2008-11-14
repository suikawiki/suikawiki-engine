#!/usr/bin/perl

use lib qw[/home/httpd/html/www/markup/html/whatpm
           /home/wakaba/work/manakai2/lib
           /home/httpd/html/swe/lib/];

use strict;

require SWE::DB::VersionControl;
my $vc = SWE::DB::VersionControl->new;

require SWE::DB::SuikaWiki3PageList;
my $sw3_pages = SWE::DB::SuikaWiki3PageList->new;
$sw3_pages->{file_name} = 'data/sw3pages.txt';

require SWE::DB::SuikaWiki3PageList2;
my $sw3_pages2 = SWE::DB::SuikaWiki3PageList2->new;
$sw3_pages2->{root_directory_name} = 'data/sw3pages/';
$sw3_pages2->{version_control} = $vc;

$sw3_pages->_load_data;

for (keys %{$sw3_pages->{data}}) {
  $sw3_pages2->set_data ($_ => $sw3_pages->{data}->{$_});
}

$sw3_pages2->save_data;

$vc->commit_changes ('generated from ' . $sw3_pages->{file_name});
