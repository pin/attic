use warnings;
use strict;

use Attic::Router;
use Log::Log4perl qw(:easy);

my $log_conf = q(
	log4perl.rootLogger = DEBUG, console

	log4perl.appender.console = Log::Log4perl::Appender::ScreenColoredLevels
	log4perl.appender.console.layout = PatternLayout
	log4perl.appender.console.layout.ConversionPattern = [%c] - %m%n
);
Log::Log4perl::init(\$log_conf);

my $dir = Attic::Router->new(home_dir => '/home/pin/Documents');
$dir->to_app;