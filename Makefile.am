cfgdir = $(datadir)/vyatta-cfg/templates
opdir = $(datadir)/vyatta-op/templates

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
	cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(cfgdir)
	cd templates; $(cpiop) $(DESTDIR)$(cfgdir)
	mkdir -p $(DESTDIR)/usr/sbin/
	cp scripts/eventwatchd.pl $(DESTDIR)/usr/sbin/eventwatchd.pl
	chmod 755 $(DESTDIR)/usr/sbin/eventwatchd.pl
	mkdir -p $(DESTDIR)/etc/eventwatchd