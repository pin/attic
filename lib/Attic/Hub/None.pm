package Attic::Hub::None;

use strict;
use warnings;

use base 'Plack::Component';

use File::Spec;

sub call {
	my $self = shift;
	my ($env) = @_;
	return [404, ['Content-type', 'text/plain'], ["Nothing!"]];
}

1;
