package Attic::File;

use warnings;
use strict;

use base 'Plack::Component';

use Plack::Request;
use Data::Dumper;
use Log::Log4perl;
use File::Spec;
use Plack::MIME;
use Plack::Util;

my $log = Log::Log4perl->get_logger();

sub prepare_app {
	my $self = shift;
	$self->{content_type} = Plack::MIME->mime_type($self->{path});
	my @stat = stat $self->{path} or die "can't stat $self->{path}: $!";
	$self->{content_length} = $stat[7];
	$self->{last_modified} = $stat[9];
	$log->info("$self->{path} file loaded");
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	open my $fh, "<:raw", $self->{path} or return [403, ['Content-type', 'text/plain'], ["can't open $self->{path}: $! "]];
	Plack::Util::set_io_path($fh, Cwd::realpath($self->{path}));
	return [200, [
		'Content-Type' => $self->{content_type} || 'text/plain',
		'Last-Modified' => HTTP::Date::time2str($self->{last_modified}),
		'Content-Length' => $self->{content_length}
	], $fh, ];
}

1;
