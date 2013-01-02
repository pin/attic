use Test::More;
use File::Spec;
use Cwd;
use Attic::Router;
use FindBin;
use Plack::Test;
use HTTP::Request::Common;
use Data::Dumper;

my $log_conf = q(
	log4perl.rootLogger = DEBUG, console

	log4perl.appender.console = Log::Log4perl::Appender::ScreenColoredLevels
	log4perl.appender.console.layout = PatternLayout
	log4perl.appender.console.layout.ConversionPattern = [%c] - %m%n
);
Log::Log4perl::init(\$log_conf);

my $documents_dir = File::Spec->catdir($FindBin::Bin, 'doc');
my $dir = Attic::Router->new(documents_dir => $documents_dir);
my $app = $dir->to_app;

test_psgi $app, sub {
	my $cb  = shift;
	
	my $root = $cb->(GET "/");
	is $root->code, 200;
	
	my $root_atom = $cb->(GET "/?type=atom");
	is $root_atom->header('Content-type'), 'text/xml';
	
	is $cb->(GET "/this-shit-does-not-exist")->code, 404;
	
	# lena.jpg
	is $cb->(GET "/lena")->header('Content-type'), 'text/html';
	is $cb->(GET "/lena.jpg?size=large")->header('Content-type'), 'image/jpeg';
};

test_psgi $app, sub {
	my $res = shift->(GET "/this-shit-does-not-exist");
	is $res->code, 404;
};

done_testing;