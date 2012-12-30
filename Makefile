all:
	# do nothing

clean:
	# do nothing

install:
	install -d $(DESTDIR)/usr/lib/attic/
	install -m644 app.psgi $(DESTDIR)/usr/lib/attic/
	install -m755 main.fcgi $(DESTDIR)/usr/lib/attic/

	install -d $(DESTDIR)/usr/lib/attic/template/
	install -m644 template/config.xsl $(DESTDIR)/usr/lib/attic/template/
	install -m644 template/directory.xsl $(DESTDIR)/usr/lib/attic/template/
	install -m644 template/date.xsl $(DESTDIR)/usr/lib/attic/template/
	install -m644 template/image.xsl $(DESTDIR)/usr/lib/attic/template/
	install -m644 template/page.xsl $(DESTDIR)/usr/lib/attic/template/
	
#	install -m644 etc/lighttpd.conf $(DESTDIR)/etc/lighttpd/conf-enabled/attic.conf
	install -m644 etc/lighttpd.conf $(DESTDIR)/etc/attic/lighttpd.conf
	install -m644 etc/home.conf $(DESTDIR)/etc/attic/
	install -m644 etc/default.conf $(DESTDIR)/etc/attic/

	# modules
	install -d $(DESTDIR)/usr/share/perl5/Attic/
	install -m644 lib/Attic/Router.pm $(DESTDIR)/usr/share/perl5/Attic/
	install -m644 lib/Attic/Hub.pm $(DESTDIR)/usr/share/perl5/Attic/
	install -m644 lib/Attic/Directory.pm $(DESTDIR)/usr/share/perl5/Attic/
	install -m644 lib/Attic/File.pm $(DESTDIR)/usr/share/perl5/Attic/
	install -m644 lib/Attic/Template.pm $(DESTDIR)/usr/share/perl5/Attic/
	install -m644 lib/Attic/Config.pm $(DESTDIR)/usr/share/perl5/Attic/

	install -d $(DESTDIR)/usr/share/perl5/Attic/Hub/
	install -m644 lib/Attic/Hub/Image.pm $(DESTDIR)/usr/share/perl5/Attic/Hub/
	install -m644 lib/Attic/Hub/None.pm $(DESTDIR)/usr/share/perl5/Attic/Hub/
	install -m644 lib/Attic/Hub/Page.pm $(DESTDIR)/usr/share/perl5/Attic/Hub/

	install -d $(DESTDIR)/usr/lib/attic/static/
	install -d $(DESTDIR)/usr/lib/attic/static/css/
	install -m664 static/css/main.css $(DESTDIR)/usr/lib/attic/static/css/
	install -m664 static/css/phone.css $(DESTDIR)/usr/lib/attic/static/css/