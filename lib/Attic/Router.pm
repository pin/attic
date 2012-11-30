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

my $log = Log::Log4perl->get_logger();

sub prepare_app {

}

sub path {
	my $self = shift;
	my ($uri) = @_;
	File::Spec->catdir($self->{home_dir}, $uri->path);
}

sub directory_app {
	my $self = shift;
	my ($uri) = @_;
	return $self->{directory_app}->{$uri->path} if exists $self->{directory_app}->{$uri->path};
	my $directory_uri = URI->new($uri->path);
	my $dir = Attic::Directory->new(uri => $directory_uri, router => $self);
	my $dir_app = eval {
		$dir->to_app;
	};
	if (my $error = $@) {
#		$log->debug("can't load directory for $uri: $error");
		return undef;
	}
	return $self->{directory_app}->{$directory_uri} = $dir_app
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
