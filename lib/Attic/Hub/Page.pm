package Attic::Hub::Page;

use strict;
use warnings;

use base 'Plack::Component';

use File::Spec;

my $log = Log::Log4perl->get_logger();

#sub prepare_app {
#	$log->info("PAGE prepared");
#}

sub modification_time {
	shift->{page}->{status}->[9];
}

sub call {
	my $self = shift;
	my ($env) = @_;
	return [200, ['Content-type', 'text/plain'], ["page: " . $self->{hub}->uri]];
}

1;
