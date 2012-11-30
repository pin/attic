package Attic::Hub::Image;

use strict;
use warnings;

use base 'Plack::Component';

use File::Spec;
use Data::Dumper;

sub call {
	my $self = shift;
	my ($env) = @_;
	my $path = File::Spec->catfile($self->{hub}->{dir}->{path}, $self->{hub}->{name} . '.html');
	return [200, ['Content-type', 'text/plain'], ["image: $path\n\n" . Dumper($self->{hub}->{dir})]];
}

1;
