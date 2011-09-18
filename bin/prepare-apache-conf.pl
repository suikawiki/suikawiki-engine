#!/usr/bin/perl
use strict;
use warnings;
no warnings 'once';
use Path::Class;

my $root_d = file (__FILE__)->dir->parent;
my $template_f = $root_d->subdir ('config')->file ('apache.conf.orig');

my $env = $ENV{X_SW_ENV} || 'wiki';

my $perl_conf_f = $root_d->subdir ('config')->file ($env . '.pl');
require ($perl_conf_f->stringify);

my $conf = "## This file is generated from $template_f.  Don't edit.\n\n" . $template_f->slurp;

my $apache_root_d = $root_d->subdir ('apache')->subdir ($env);
$apache_root_d->subdir ('logs')->mkpath;
$apache_root_d->subdir ('run')->mkpath;
$apache_root_d->subdir ('conf')->mkpath;
$apache_root_d->subdir ('conf')->file ('mime.types')->openw;

my $sw_lib_d = $root_d->subdir ('lib');

$conf =~ s/%%APACHEROOT%%/$apache_root_d->absolute->stringify/ge;
$conf =~ s/%%SWLIB%%/$sw_lib_d->absolute->stringify/ge;
$conf =~ s/%%APACHEMODULES%%/$SuikaWiki5::Main::apache_modules_dir_name/g;
$conf =~ s/%%APACHESERVERNAME%%/$SuikaWiki5::Main::apache_server_name/g;
$conf =~ s/%%APACHESERVERPORT%%/$SuikaWiki5::Main::apache_server_port/g;
$conf =~ s/%%APACHESERVERADMIN%%/$SuikaWiki5::Main::apache_server_admin/g;
$conf =~ s/%%SWSCRIPTNAME%%/$SuikaWiki5::Main::sw_script_name/g;
$conf =~ s/%%SWENV%%/$env/g;
$conf =~ s/%%EDITREALM%%/$SuikaWiki5::Main::edit_realm/g;
$conf =~ s/%%EDITGROUP%%/$SuikaWiki5::Main::edit_group/g;
$conf =~ s/%%EDITHTPASSWD%%/$SuikaWiki5::Main::edit_htpasswd_file_name/g;
$conf =~ s/%%EDITHTGROUP%%/$SuikaWiki5::Main::edit_htgroup_file_name/g;

my $conf_f = $root_d->subdir ('config')->file ('apache.' . $env . '.conf');
my $f = $conf_f->openw;
print $f $conf;
