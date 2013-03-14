# plackup -Ilib -r -R template

use warnings;
use strict;

use Attic::Router;
use Log::Log4perl qw(:easy);
use Attic::Config;
use Plack::Builder;
use FindBin;

if (my $log_path = Attic::Config->value('log_path')) {
	my $log_conf = qq(
		log4perl.rootLogger = DEBUG, log_file
		log4perl.appender.log_file = Log::Log4perl::Appender::File
		log4perl.appender.log_file.filename = $log_path
		log4perl.appender.log_file.mode = append
		log4perl.appender.log_file.layout = PatternLayout
		log4perl.appender.log_file.layout.ConversionPattern = %d [%p] %m%n
		log4perl.appender.log_file.recreate = 1
		log4perl.appender.log_file.recreate_check_signal = HUP
		log4perl.appender.log_file.Threshold = DEBUG
	);
	Log::Log4perl::init(\$log_conf);
}
else {
	my $log_conf = q(
		log4perl.rootLogger = DEBUG, console
	
		log4perl.appender.console = Log::Log4perl::Appender::ScreenColoredLevels
		log4perl.appender.console.layout = PatternLayout
		log4perl.appender.console.layout.ConversionPattern = [%c] - %m%n
	);
	Log::Log4perl::init(\$log_conf);
}

my $dir = Attic::Router->new(documents_dir => Attic::Config->value('documents_dir'));
my $app = $dir->to_app;

builder {
	enable "Plack::Middleware::Static", path => qr{^/(images|js|css|fonts)/}, root => File::Spec->catdir($FindBin::Bin, 'static');
	enable "Plack::Middleware::Rewrite", rules => sub {
		return 301 if 0
			or s!^/misc/uaz/check-list\.html$!/2005/uaz/check-list!
			or s!^/misc/uaz/transmission-gear-ratio\.html$!/2005/uaz/transmission-gear-ratio!
			or s!^/misc/uaz/transmission\.html$!/2005/uaz/transmission-double-clutch-shift!
			or s!^/misc/uaz/spares-for-travel\.html$!/2005/uaz/spares-for-travel!
			or s!^/story/tumcha(/?)$!/2003/tumcha/!
			or s!^/story/usinsk(/?)$!/2005/usinsk/!
			or s!^/story/usinsk/map-with-track.jpg$!/2005/usinsk/map-with-track.jpg!
			or s!^/photo/catalog/nature\.html$!/!
			or s!^/learn/practical-work/practical-work\.doc$!/2002/practical-work/practical-work.doc!
			or s!^/dmitri/where(.*)$!/2010/dmitri/where$1!
			or s!^/anastasia/where(.*)$!/2011/anastasia/where$1!
			or 0;
		return undef unless $_ =~ m|^/p|;
		return 301 if 0
			or s!^/photo/(0326|0327|1294|1830|2309|3006|3212|5282|5559|5560|8298|6170)/(.*)-(\d\d)\.html$!/2001/$1/$3-$2!
			or s!^/photo/(0326|0327|1294|1830|2309|3006|3212|5282|5559|5560|8298|6170)/(.*)-(\d\d)\.3\.jpg$!/2001/$1/$3-$2.tif!
			or s!^/photo/(0326|0327|1294|1830|2309|3006|3212|5282|5559|5560|8298|6170)/(.*)-(\d\d)\.1\.jpg$!/2001/$1/$3-$2.tif!
			or s!^/photo/(0406|0407|0957|1696|2181|3604|3605|4001|4054|7085|9053|9055)/(.*)-(\d\d)\.html$!/2002/$1/$3-$2!
			or s!^/photo/(0406|0407|0957|1696|2181|3604|3605|4001|4054|7085|9053|9055)/(.*)-(\d\d)\.3\.jpg$!/2002/$1/$3-$2.tif!
			or s!^/photo/(0406|0407|0957|1696|2181|3604|3605|4001|4054|7085|9053|9055)/(.*)-(\d\d)\.1\.jpg$!/2002/$1/$3-$2.tif!
			or s!^/photo/(3163|4346|0505|1252)/(.*)-(\d\d)\.html$!/2003/$1/$3-$2!
			or s!^/photo/(3163|4346|0505|1252)/(.*)-(\d\d)\.3\.jpg$!/2003/$1/$3-$2.tif!
			or s!^/photo/(3163|4346|0505|1252)/(.*)-(\d\d)\.1\.jpg$!/2003/$1/$3-$2.tif!
			or s!^/photo/(3091|3092|3093|3143|3144|3145|3146|3147|3148|3149|3150|3151|3152)/(.*)-(\d\d)\.html$!/2003/tumcha/$1/$3-$2!
			or s!^/photo/(3091|3092|3093|3143|3144|3145|3146|3147|3148|3149|3150|3151|3152)/(.*)-(\d\d)\.3\.jpg$!/2003/tumcha/$1/$3-$2.tif!
			or s!^/photo/(3091|3092|3093|3143|3144|3145|3146|3147|3148|3149|3150|3151|3152)/(.*)-(\d\d)\.1\.jpg$!/2003/tumcha/$1/$3-$2.tif!
			or s!^/photo/(0510|1258|1259|4174)/(.*)-(\d\d)\.html$!/2004/$1/$3-$2!
			or s!^/photo/(0510|1258|1259|4174)/(.*)-(\d\d)\.3\.jpg$!/2004/$1/$3-$2.tif!
			or s!^/photo/(0510|1258|1259|4174)/(.*)-(\d\d)\.1\.jpg$!/2004/$1/$3-$2.tif!
			or s!^/photo/0314/(.*)-(\d\d)\.html$!/2005/usinsk/0314/$2-$1!
			or s!^/photo/0314/(.*)-(\d\d)\.3\.jpg$!/2005/usinsk/0314/$2-$1.tif!
			or s!^/photo/0314/(.*)-(\d\d)\.1\.jpg$!/2005/usinsk/0314/$2-$1.tif!
			or 0;
	};
	$app;
};
