all:

WGET = wget
CURL = curl
GIT = git

updatenightly: local/bin/pmbp.pl
	$(CURL) https://gist.githubusercontent.com/motemen/667573/raw/git-submodule-track | sh
	$(GIT) add modules
	perl local/bin/pmbp.pl --update
	$(GIT) add config

## ------ Setup ------

deps: git-submodules pmbp-install

git-submodules:
	$(GIT) submodule update --init

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/bin/pmbp.pl
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install \
	    --create-perl-command-shortcut local-server=bin/local-server

## ------ Server configuration ------

# Need SERVER_ENV!
server-config: daemontools-config batch-server

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

# Need SERVER_ENV!
batch-server:
	mkdir -p local/config/cron.d
	cd config/cron.d.in && ls *-cron | \
            xargs -l1 -i% -- sh -c "cat % | sed 's/@@ROOT@@/$(subst /,\/,$(abspath .))/g' > ../../local/config/cron.d/$(SERVER_ENV)-%"

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps

test-main:
	$(PROVE) t/*.t

## ------ Deployment ------

CINNAMON_GIT_REPOSITORY = git://github.com/wakaba/cinnamon.git

cinnamon:
	mkdir -p local
	cd local && (($(GIT) clone $(CINNAMON_GIT_REPOSITORY)) || (cd cinnamon && $(GIT) pull)) && cd cinnamon && $(MAKE) deps
	echo "#!/bin/sh" > ./cin
	echo "exec $(abspath local/cinnamon/perl) $(abspath local/cinnamon/bin/cinnamon) \"\$$@\"" >> ./cin
	chmod ugo+x ./cin
