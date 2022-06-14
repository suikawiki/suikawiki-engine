all:

WGET = wget
CURL = curl
GIT = git

updatenightly: local/bin/pmbp.pl clean build
	$(CURL) https://gist.githubusercontent.com/motemen/667573/raw/git-submodule-track | sh
	$(GIT) add modules
	perl local/bin/pmbp.pl --update
	$(GIT) add config scripts/time.js

clean:
	rm -f scripts/time.js

build: scripts/time.js

scripts/time.js: local/time.js local/suncalc.js local/suncalc-LICENSE
	cat local/time.js > $@
	cat local/suncalc.js >> $@
	echo "/*" >> $@
	cat local/suncalc-LICENSE >> $@
	echo "*/" >> $@

local/time.js:
	$(WGET) -O $@ https://raw.githubusercontent.com/wakaba/timejs/master/src/time.js
local/suncalc.js:
	$(WGET) -O $@ https://raw.githubusercontent.com/mourner/suncalc/master/suncalc.js
local/suncalc-LICENSE:
	$(WGET) -O $@ https://raw.githubusercontent.com/mourner/suncalc/master/LICENSE

## ------ Setup ------

deps: git-submodules pmbp-install

git-submodules:
	$(GIT) submodule update --init

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://raw.githubusercontent.com/wakaba/perl-setupenv/master/bin/pmbp.pl
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install \
	    --create-perl-command-shortcut local-server=bin/local-server

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

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps

test-main:
	$(PROVE) t/*.t

## ------ Deployment ------

CINNAMON_GIT_REPOSITORY = https://github.com/wakaba/cinnamon.git

cinnamon:
	mkdir -p local
	cd local && (($(GIT) clone $(CINNAMON_GIT_REPOSITORY)) || (cd cinnamon && $(GIT) pull)) && cd cinnamon && $(MAKE) deps
	echo "#!/bin/sh" > ./cin
	echo "exec $(abspath local/cinnamon/perl) $(abspath local/cinnamon/bin/cinnamon) \"\$$@\"" >> ./cin
	chmod ugo+x ./cin

## License: Public Domain.
