package Attic::Router;

use warnings;
use strict;

use base 'Plack::Component';

use Plack::Request;
use Data::Dumper;
use Log::Log4perl;
use File::Spec;
use Attic::Directory;
use URI;
use Fcntl ':mode';

my $log = Log::Log4perl->get_logger();

sub path {
	my $self = shift;
	my ($uri) = @_;
	my @segments = File::Spec->no_upwards(grep {$_} $uri->path_segments);
	my $path = File::Spec->catdir($self->{documents_dir}, @segments);
}

sub directory {
	my $self = shift;
	my ($uri, $stat) = @_;
	unless ($stat) {
		$stat = [stat $self->path($uri)] or do {
			delete $self->{directories}->{$uri->path} if exists $self->{directories}->{$uri->path};
			return undef;
		};
	}
	unless (S_ISDIR($stat->[2])) {
		return undef;
	}
	if (my $directory = $self->{directories}->{$uri->path}) {
		return $directory if $directory->modification_time == $stat->[9];
	}
	my $directory_uri = URI->new($uri->path);
	my $dir = Attic::Directory->new(uri => $directory_uri, router => $self, status => $stat);
	$log->debug("create directory instance: " . $dir->path . ' (' . $uri . ')');
	return $self->{directories}->{$uri->path} = $dir;
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	if (my $dir = $self->directory($request->uri)) {
		return $dir->app->($env);
	}
	else {
		my ($parent_uri, $name) = Attic::Directory->pop_name($request->uri);
		if (my $parent_dir = $self->directory($parent_uri)) {
			return $parent_dir->app->($env);
		}
		else {
			$log->error("$parent_uri not found");
			return [404, ['Content-type', 'text/plain'], [$request->path . ' not found']];
		}
	}
}

1;
