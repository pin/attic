package Attic;

use warnings;
use strict;

use Getopt::Long qw(GetOptionsFromArray);
use Log::Log4perl;
use Attic::File;
use Attic::Config;
use File::Spec;
use URI;
use Attic::Directory;
use Attic::Router;
use Data::Dumper;

my $log = Log::Log4perl->get_logger();

sub run_bubu {
	my $class = shift;
	$log->info('lala');
}

sub load_file {
	my $class = shift;
	my ($path) = @_;
	my @s = stat $path or die "can't open $path: $!";
	die "not a file: $path" unless -f $path;
	my $documents_dir = Attic::Config->value('documents_dir');
	my $uri = URI->new(File::Spec->abs2rel($path, $documents_dir));
	my ($dir_uri, $name) = Attic::Directory->pop_name($uri);
	my $router = Attic::Router->new(documents_dir => Attic::Config->value('documents_dir'));
	my $dir = $router->directory($dir_uri);
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

1;