package Attic::Router;

use warnings;
use strict;

use base 'Plack::Component';

use Plack::Request;
use Data::Dumper;
use Log::Log4perl;
use File::Spec;
use Attic::Directory;

my $log = Log::Log4perl->get_logger();

sub prepare_app {

}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	
	my $path = File::Spec->catdir($self->{home_dir}, $request->path);
	
	my ($parent_uri) = Attic::Directory->pop_filename($request->uri);
	my $parent_path = $parent_uri ? File::Spec->catdir($self->{home_dir}, $parent_uri->path) : undef;

	my $dir = eval {
		Attic::Directory->new(path => $path, uri => $request->uri)->to_app;
	};
	if (my $error = $@) {
		if ($parent_path) {
			my $dir = eval {
				Attic::Directory->new(path => $parent_path, uri => $parent_uri)->to_app;
			};
			if (my $error = $@) {
				$log->error("can't load $path nor $parent_path as directory: $error");
				return [404, ['Content-type', 'text/plain'], [$request->path . ' not found']];
			}
			else {
				return $dir->($env);
			}
		}
		else {
			$log->error("can't load $path as directory: $error");
			return [404, ['Content-type', 'text/plain'], [$request->path . ' not found']];
		}
	}
	else {
		return $dir->($env);
	}
}

1;
