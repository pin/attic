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

my $log = Log::Log4perl->get_logger();

sub prepare_app {
	my $self = shift;
	opendir my $dh, $self->{path} or die "can't open $self->{path}: $!";
	while (my $f = readdir $dh) {
		next if $f eq '.' or $f eq '..';
		$self->register_entry($f);
	}
	closedir $dh;
	$log->info("$self->{path} directory loaded");
}

sub register_entry {
	my $self = shift;
	my ($name) = @_;
	my $path = File::Spec->catfile($self->{path}, $name);
	my @s = stat $path or do {
		$log->debug("can't stat $path: $!");
		return;
	};
	if (S_ISREG($s[2])) {
		my $file = Attic::File->new(path => $path)->to_app;
		$self->{files}->{$name} = $file;
		my @t = split /\./, $name;
		pop @t;
		while (@t) {
			my $h = join '.', @t;
			unless (exists $self->{hubs}->{$h}) {
				$self->{hubs}->{$h} = Attic::Hub->new(name => $h, dir => $self);
			}
			$self->{hubs}->{$h}->add_file($path);
			pop @t;
		}
	}
	elsif (S_ISDIR($s[2])) {
		$self->{dirs}->{$name} = 1;
	}
	elsif (S_ISLNK($s[2])) {
		$self->{links}->{$name} = 1;
	}
	else {
		$log->debug("ignore $name");
	}
}

sub find_entry {
	my $self = shift;
	my ($name) = @_;
	if (exists $self->{files}->{$name}) {
		return $self->{files}->{$name};
	}
	elsif (exists $self->{hubs}->{$name}) {
		return $self->{hubs}->{$name};
	}
	return undef;
}

sub pop_filename {
	my $class = shift;
	my ($uri) = @_;
	return undef if $uri->path eq '/';
	my @segments = $uri->path_segments;
	my $filename = pop @segments;
	$uri->path_segments(@segments, '');
	return ($uri, $filename);
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	if ($request->uri eq $self->{uri}) {
		return [200, ['Content-type', 'text/plain'], ["$self->{uri}\n\n" . Dumper($self, $env)]];
	}
	else {
		my ($parent_uri, $filename) = __PACKAGE__->pop_filename($request->uri);
		if ($parent_uri and $parent_uri eq $self->{uri}) {
			if (my $entry = $self->find_entry($filename)) {
				return $entry->($env);
			}
			else {
				return [404, ['Content-type', 'text/plain'], ["no $filename found in " . $parent_uri->path]];
			}
		}
		else {
			return [500, ['Content-type', 'text/plain'], ["directory at $self->{uri} knows nothing about $parent_uri"]];
		}
	}
	return [404, ['Content-type', 'text/plain'], ["no such directory: $self->{path}"]];
}

1;
