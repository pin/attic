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

my $app = Attic::Router->new(documents_dir => Attic::Config->value('documents_dir'))->to_app();

builder {
	enable "Plack::Middleware::Static", path => qr{^/(images|js|css|fonts)/}, root => File::Spec->catdir($FindBin::Bin, 'static');
	$app;
};
