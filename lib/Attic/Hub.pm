package Attic::Hub;

use warnings;
use strict;

use base 'Plack::Component';

use Plack::Request;
use Data::Dumper;
use Log::Log4perl;
use File::Spec;

my $log = Log::Log4perl->get_logger();

sub prepare_app {
	my $self = shift;
	$log->info("$self->{name} hub loaded");
}

sub add_file {
	my $self = shift;
	my ($path) = @_;
	$self->{files}->{$path} = 1;
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	return [200, ['Content-type', 'text/plain'], ["HUB $self->{name} at $self->{dir}->{uri}\n\n" . Dumper($self)]];
}

1;
