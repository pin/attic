package Attic::Media::File;

use warnings;
use strict;

use Log::Log4perl;
use URI;

use base 'Attic::Media::Base';

my $log = Log::Log4perl->get_logger();

sub accept {
	1;
}

sub priority {
	100;
}

sub process {
	my $self = shift;
	my ($request, $media) = @_;
	my $path = $self->{router}->path(URI->new($media->{uri}));
	if (my @s = stat $path) {
		return Attic::Media->serve_file($request, $path, \@s);
	}
	else {
		return [500, ['Content-type', 'text/plain'], ["can't stat $path: $!"]];
	}
}

1;
