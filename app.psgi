use warnings;
use strict;

use Attic::Router;
use Log::Log4perl qw(:easy);

my $log_conf = q(
	log4perl.rootLogger = DEBUG, console, syslog

	log4perl.appender.console = Log::Log4perl::Appender::ScreenColoredLevels
	log4perl.appender.console.layout = PatternLayout
	log4perl.appender.console.layout.ConversionPattern = [%c] - %m%n

	log4perl.appender.syslog = Log::Dispatch::Syslog
	log4perl.appender.syslog.min_level = debug
	log4perl.appender.syslog.layout = Log::Log4perl::Layout::SimpleLayout
	log4perl.appender.syslog.ident = attic
	log4perl.appender.syslog.facility = daemon
);
Log::Log4perl::init(\$log_conf);

my $dir = Attic::Router->new(home_dir => '/home/pin/Documents');
$dir->to_app;