X_SW_ENV ?= wiki

all: conf

conf: config/apache.$(X_SW_ENV).conf

config/apache.$(X_SW_ENV).conf: bin/prepare-apache-conf.pl config/apache.conf.orig
	X_SW_ENV=$(X_SW_ENV) perl bin/prepare-apache-conf.pl > $@

start:
	-/usr/sbin/httpd -f $(shell pwd)/config/apache.$(X_SW_ENV).conf -k start
	tail -f apache/$(X_SW_ENV)/logs/*_log
stop:
	/usr/sbin/httpd -f $(shell pwd)/config/apache.$(X_SW_ENV).conf -k stop
restart:
	-/usr/sbin/httpd -f $(shell pwd)/config/apache.$(X_SW_ENV).conf -k restart
	tail -f apache/$(X_SW_ENV)/logs/*_log
