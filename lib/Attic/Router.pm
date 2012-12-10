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
	my $path = File::Spec->catdir($self->{home_dir}, @segments);
}

sub directory {
	my $self = shift;
	my ($uri, $stat) = @_;
	return $self->{directories}->{$uri->path} if exists $self->{directories}->{$uri->path};
	my $directory_uri = URI->new($uri->path);
	my $dir = Attic::Directory->new(uri => $directory_uri, router => $self);
	if ($stat) {
		$dir->{status} = $stat;
	}
	else {
		my @s = stat $dir->path or do {
			$log->debug("can't stat " . $dir->path . ": $!");
			return undef;
		};
		unless (S_ISDIR($s[2])) {
			return undef;
		}
		$dir->{status} = \@s;
	}
	return $self->{directories}->{$uri->path} = $dir;
}

sub directory_app {
	my $self = shift;
	my ($uri) = @_;
	return $self->{directory_app}->{$uri->path} if exists $self->{directory_app}->{$uri->path};
	my $dir = $self->directory($uri) or return undef;
	return $self->{directory_app}->{$dir->{uri}} = $dir->to_app
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	
	if (my $dir_app = $self->directory_app($request->uri)) {
		return $dir_app->($env);
	}
	else {
		my ($parent_uri, $name) = Attic::Directory->pop_name($request->uri);
		if (my $parent_dir_app = $self->directory_app($parent_uri)) {
			return $parent_dir_app->($env);
		}
		else {
			$log->error("$parent_uri not found");
			return [404, ['Content-type', 'text/plain'], [$request->path . ' not found']];
		}
	}
}

1;
