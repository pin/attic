package Attic::Directory;

use strict;
use warnings;

use base 'Plack::Component';

use Plack::Request;
use Data::Dumper;
use Log::Log4perl;
use File::Spec;
use Attic::File;
use Fcntl ':mode';
use Attic::Hub;
use XML::Atom::Feed; $XML::Atom::DefaultVersion = '1.0';

my $log = Log::Log4perl->get_logger();

sub prepare_app {
	my $self = shift;
	opendir my $dh, $self->path or die "can't open " . $self->path . ": $!";
	while (my $f = readdir $dh) {
		next if $f =~ /^\./;
		my $path = File::Spec->catfile($self->path, $f);
		my @s = stat $path or do {
			$log->debug("can't stat $path: $!");
			return;
		};
		$self->{stats}->{$f} = \@s;
		if (S_ISREG($s[2])) {
			my $file = $self->{files}->{$f} = Attic::File->new(dir => $self, name => $f);
			my @t = split /\./, $f;
			pop @t;
			while (@t) {
				my $h = join '.', @t;
				unless (exists $self->{hubs}->{$h}) {
					$self->{hubs}->{$h} = Attic::Hub->new(name => $h, dir => $self);
				}
				$self->{hubs}->{$h}->add_file($file);
				pop @t;
			}
		}
	}
	closedir $dh;
	$log->info("$self->{uri} directory init complete");
}

sub path {
	my $self = shift;
	return $self->{router}->path($self->{uri});
}

sub pop_name {
	my $class = shift;
	my ($uri) = @_;
	return undef if $uri->path eq '/';
	my @segments = $uri->path_segments;
	my $name = pop @segments;
	$uri->path_segments(@segments, '');
	return ($uri, $name);
}

sub hub_app {
	my $self = shift;
	my ($name) = @_;
	return $self->{hub_app}->{$name} if exists $self->{hub_app}->{$name};
	if (exists $self->{hubs}->{$name}) {
		return $self->{hub_app}->{$name} = $self->{hubs}->{$name}->to_app;
	}
	return undef;
}

sub file_app {
	my $self = shift;
	my ($name) = @_;
	return $self->{file_app}->{$name} if exists $self->{file_app}->{$name};
	if (exists $self->{files}->{$name}) {
		return $self->{file_app}->{$name} = $self->{files}->{$name}->to_app;
	}
	return undef;
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	if ($request->uri->path eq $self->{uri}->path) {
		if (my $hub_app = $self->hub_app('index')) {
			$log->debug("directory request to " . $request->uri->path . " goes to index");
			return $hub_app->($env);
		}
		else {
			return [200, ['Content-type', 'text/plain'], ["$self->{uri}\n\n" . Dumper($self, $env)]];
		}
	}
	else {
		my ($parent_uri, $name) = __PACKAGE__->pop_name($request->uri);
		if ($parent_uri and $parent_uri->path eq $self->{uri}->path) {
			if (my $hub_app = $self->hub_app($name)) {
				return $hub_app->($env);
			}
			elsif (my $file_app = $self->file_app($name)) {
				return $file_app->($env);
			}
			else {
				return [404, ['Content-type', 'text/plain'], ["$name not found at " . $parent_uri->path]];
			}
		}
		else {
			return [500, ['Content-type', 'text/plain'], ["directory at $self->{uri} knows nothing about $parent_uri"]];
		}
	}
	return [404, ['Content-type', 'text/plain'], ["no such directory: " . $self->path]];
}

1;
