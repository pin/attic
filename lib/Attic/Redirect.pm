package Attic::Redirect;

use warnings;
use strict;

use base 'Plack::Middleware';

use Plack::Request;
use Data::Dumper;
use Log::Log4perl;
use Config::IniFiles;

my $log = Log::Log4perl->get_logger();

sub prepare_app {
	my $self = shift;
	my $path = $self->{path} or die "missing configuration file path";
	open my $fh, '<', $path or die "can't read $path: $!";
	while (my $line = <$fh>) {
		chomp $line;
		next unless $line;
		my ($source, $target) = split "\t", $line;
		$log->error("duplicate $source in $path") if exists $self->{permanent}->{$source};
		$self->{permanent}->{$source} = $target;
	}
	close $fh; 
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	if (exists $self->{permanent}->{$request->path}) {
		my $uri = $self->{permanent}->{$request->path};
		return [301, ['Location' => $uri], ["follow $uri"]];
	}
	my $response = $self->app->($env);
	return $response;
}

1;
