package Attic::Hub::Page;

use strict;
use warnings;

use base 'Plack::Component';

use File::Spec;

my $log = Log::Log4perl->get_logger();

#sub prepare_app {
#	$log->info("PAGE prepared");
#}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $path = File::Spec->catfile($self->{hub}->{dir}->{path}, $self->{hub}->{name} . '.html');
	return [200, ['Content-type', 'text/plain'], ["page: $path"]];
}

1;
