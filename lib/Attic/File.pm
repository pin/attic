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
use URI;

my $log = Log::Log4perl->get_logger();

sub prepare_app {
	my $self = shift;
	$self->{content_length} = $self->{dir}->{stats}->{$self->{name}}->[7];
	$self->{last_modified} = $self->{dir}->{stats}->{$self->{name}}->[9];
	$log->info($self->uri . " file loaded");
}

sub path {
	my $self = shift;
	File::Spec->catfile($self->{dir}->path, $self->{name});
}

sub uri {
	my $self = shift;
	my $uri = URI->new($self->{dir}->{uri});
	my @s = $uri->path_segments;
	pop @s;
	$uri->path_segments(@s, $self->{name});
	return $uri;
}

sub content_type {
	my $self = shift;
	Plack::MIME->mime_type($self->path) || 'text/plain';
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	open my $fh, "<:raw", $self->path or return [403, ['Content-type', 'text/plain'], ["can't open " . $self->path . ": $! "]];
	Plack::Util::set_io_path($fh, Cwd::realpath($self->path));
	return [200, [
		'Content-Type' => $self->content_type,
		'Last-Modified' => HTTP::Date::time2str($self->{last_modified}),
		'Content-Length' => $self->{content_length}
	], $fh, ];
}

1;
