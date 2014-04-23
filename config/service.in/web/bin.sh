#!/bin/sh
exec 2>&1
export LANG=C
export TZ=UTC
export SW_DB_DIR=@@ROOT@@/../sw-data
export KARASUMA_CONFIG_JSON=@@ROOT@@/config/@@ENV@@.json
export KARASUMA_CONFIG_FILE_DIR_NAME=@@ROOT@@/local/keys/@@ENV@@
export WEBUA_DEBUG=`@@ROOT@@/perl @@ROOT@@/modules/karasuma-config/bin/get-json-config.pl env_WEBUA_DEBUG text`
port=`@@ROOT@@/perl @@ROOT@@/modules/karasuma-config/bin/get-json-config.pl web_port text`

eval "exec setuidgid @@USER@@ @@ROOT@@/plackup \
    $PLACK_COMMAND_LINE_ARGS \
    --host 127.0.0.1 -p $port @@ROOT@@/bin/server.psgi"
