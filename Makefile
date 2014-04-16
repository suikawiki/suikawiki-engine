all:

WGET = wget
CURL = curl
GIT = git

updatenightly: local/bin/pmbp.pl
	$(CURL) https://gist.githubusercontent.com/motemen/667573/raw/git-submodule-track | sh
	$(GIT) add modules bin/modules t_deps/modules
	perl local/bin/pmbp.pl --update
	$(GIT) add config

## ------ Setup ------

deps: git-submodules
	cd modules/SWE && $(MAKE) deps

git-submodules:
	$(GIT) submodule update --init

## ------ Server configuration ------

# Need SERVER_ENV!
server-config: daemontools-config

# Need SERVER_ENV!
install-server-config: install-daemontools-config

SERVER_ENV = HOGE
SERVER_ARGS = \
    APP_NAME=suikawiki \
    SERVER_INSTANCE_NAME="suikawiki-$(SERVER_ENV)" \
    SERVER_INSTANCE_CONFIG_DIR="$(abspath ./config)" \
    ROOT_DIR="$(abspath .)" \
    LOCAL_DIR="$(abspath ./local)" \
    LOG_DIR=/var/log/app \
    SYSCONFIG="/etc/sysconfig/suikawiki" \
    SERVICE_DIR="/service" \
    SERVER_USER=wakaba LOG_USER_GROUP=wakaba.wakaba \
    SERVER_ENV="$(SERVER_ENV)"

# Need SERVER_ENV!
daemontools-config:
	$(MAKE) --makefile=Makefile.service all $(SERVER_ARGS) SERVER_TYPE=web

# Need SERVER_ENV!
install-daemontools-config:
	mkdir -p /var/log/app
	chown wakaba.wakaba /var/log/app
	$(MAKE) --makefile=Makefile.service install $(SERVER_ARGS) SERVER_TYPE=web

## ------ Deployment ------

CINNAMON_GIT_REPOSITORY = git://github.com/wakaba/cinnamon.git

cinnamon:
	mkdir -p local
	cd local && (($(GIT) clone $(CINNAMON_GIT_REPOSITORY)) || (cd cinnamon && $(GIT) pull)) && cd cinnamon && $(MAKE) deps
	echo "#!/bin/sh" > ./cin
	echo "exec $(abspath local/cinnamon/perl) $(abspath local/cinnamon/bin/cinnamon) \"\$$@\"" >> ./cin
	chmod ugo+x ./cin
