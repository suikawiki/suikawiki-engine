package SuikaWiki5::Main;
use strict;
use warnings;
use Path::Class;

my $root_d = file (__FILE__)->dir->parent;

our $homepage_name = 'HomePage';
our $license_name = 'WikiPageLicense';
our $help_page_name = 'HelpPage';

our $style_url = q</swe/styles/sw>;
our $script_url = q</swe/scripts/sw>;
our $cvs_archives_url = q</gate/cvs/melon/pub/suikawiki/sw4data/>;

our $sw3_db_dir_name = q[/home/wakaba/server/sw3/wikidata/page/];
our $db_dir_name = q[/data1/sw/sw4data/];

our $apache_modules_dir_name = q[/usr/lib64/httpd/modules];
our $apache_server_name = q[suikawiki];
our $apache_server_port = 10085;
our $apache_server_admin = q[webmaster@suika.fam.cx];

our $sw_script_name = q[/~wakaba/wiki/sw];

our $edit_realm = q[SuikaWiki];
our $edit_group = q[suikawiki];
our $edit_htpasswd_file_name = q[/home/wakaba/public_html/pbin/accounts/data/htpasswd];
our $edit_htgroup_file_name = q[/home/wakaba/public_html/pbin/accounts/data/htgroup];

1;
