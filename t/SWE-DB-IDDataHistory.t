#!/bin/sh
echo "1..1"
rootdir=`dirname $0`/..
($rootdir/perl -c $rootdir/lib/SWE/DB/IDDataHistory.pm && echo "ok 1") || echo "not ok 1"
