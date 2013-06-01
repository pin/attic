package Attic;

use warnings;
use strict;

use Getopt::Long qw(GetOptionsFromArray);
use Log::Log4perl;
use Attic::Config;
use File::Spec;
use URI;
use Attic::Directory;
use Attic::Router;
use Data::Dumper;

use Log::Log4perl qw(:easy);

# do not use colored log with TM or cron
my $log_conf = $ENV{TERM} ? q(
	log4perl.rootLogger = DEBUG, console
	log4perl.appender.console = Log::Log4perl::Appender::ScreenColoredLevels
	log4perl.appender.console.layout = SimpleLayout
) : q(
	log4perl.rootLogger = DEBUG, console
	log4perl.appender.console = Log::Log4perl::Appender::Screen
	log4perl.appender.console.layout = SimpleLayout
);
Log::Log4perl::init(\$log_conf);

my $log = Log::Log4perl->get_logger();

my $router = Attic::Router->new(documents_dir => Attic::Config->value('documents_dir'));
$router->prepare_app();

sub run_index {
	my $class = shift;
	my ($uri) = @_;
	$uri = $uri ? URI->new($uri) : URI->new('/');
	my $feed = $router->discover_feed($uri);
	my $feeds = $router->{db}->list_feed_feeds($uri);
	my $entries = $router->{db}->list_feed_entries($uri);
	foreach my $entry (@$entries) {
		my @images = grep {$_->type =~ /^image\// and $_->rel eq 'alternate'} $entry->link;
		foreach my $image_link (@images) {
			my $media = $router->{db}->load_media($image_link->href);
			my $path = $router->path(URI->new($image_link->href));
			$router->{media}->module($media)->index($path, $media);
		}
	}
	foreach my $feed (@$feeds) {
		my ($self_link) = grep {$_->rel eq 'self'} $feed->link;
		$class->run_index($self_link->href);
	}
}

sub load_file {
	my $class = shift;
	my ($path) = @_;
	my @s = stat $path or die "can't open $path: $!";
	die "not a file: $path" unless -f $path;
	my $documents_dir = Attic::Config->value('documents_dir');
	my $uri = URI->new(File::Spec->abs2rel($path, $documents_dir));
	my ($dir_uri, $name) = Attic::Db->pop_name($uri);
	my $router = Attic::Router->new(documents_dir => Attic::Config->value('documents_dir'));
	$router->prepare_app();
	my $dir = $router->discover_feed($dir_uri);
	return Attic::File->new(dir => $dir, name => $name, status => \@s);
}

sub run_title {
	my $class = shift;
	Getopt::Long::GetOptionsFromArray(\@_,
		'delete' => \my $is_delete
	) or die "wrong options\n" . $class->help_title;
	my ($path, $title) = @_;
	die "missing path\n" . $class->help_title unless $path;
	die "ambigous options\n" . $class->help_title if $title and $is_delete;
	my $file = $class->load_file($path);
	if ($title) {
		$file->xmp_param('dc', 'Title', $title);
		print $file->xmp_param('dc', 'Title') . "\n";
	}
	elsif ($is_delete) {
		$file->xmp_param('dc', 'Title', undef);
	}
	else {
		my $title = $file->xmp_param('dc', 'Title');
		print $title . "\n" if defined $title;
	}
}
sub help_title { <<HELP
usage: title [--delete] <path> [title]
HELP
}

sub run_description {
	my $class = shift;
	Getopt::Long::GetOptionsFromArray(\@_,
		'delete' => \my $is_delete
	) or die "wrong options\n" . $class->help_description;
	my ($path, $description) = @_;
	die "missing path\n" . $class->help_description unless $path;
	die "ambigous options\n" . $class->help_description if $description and $is_delete;
	my $file = $class->load_file($path);
	if ($description) {
		$file->xmp_param('dc', 'Description', $description);
		print $file->xmp_param('dc', 'Description') . "\n";
	}
	elsif ($is_delete) {
		$file->xmp_param('dc', 'Description', undef);
	}
	else {
		my $description = $file->xmp_param('dc', 'Description');
		print $description . "\n" if defined $description;
	}
}
sub help_description { <<HELP
usage: desctiption [--delete] <path> [desctiption]
HELP
}

1;
