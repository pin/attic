# plackup -Ilib -r -R template

use warnings;
use strict;

use Attic::Router;
use Log::Log4perl qw(:easy);
use Attic::Config;
use Plack::Builder;
use FindBin;
use Attic::Redirect;

my $log_conf = q(
	log4perl.rootLogger = DEBUG, console

	log4perl.appender.console = Log::Log4perl::Appender::ScreenColoredLevels
	log4perl.appender.console.layout = PatternLayout
	log4perl.appender.console.layout.ConversionPattern = [%c] - %m%n
);
Log::Log4perl::init(\$log_conf);

my $dir = Attic::Router->new(home_dir => Attic::Config->value('documents_dir'));
my $app = $dir->to_app;

builder {
	enable "Plack::Middleware::Static", path => qr{^/(images|js|css|fonts)/}, root => File::Spec->catdir($FindBin::Bin, 'static');
	enable "+Attic::Redirect", path => Attic::Config->value('legacy_tsv_path');
	$app;
};
