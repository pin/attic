package Attic::Media;

use warnings;
use strict;

#use Data::Dumper;
use Log::Log4perl;
#use File::Spec;
use Plack::MIME;
#use Plack::Util;
#use URI;
#use Image::ExifTool;
#use File::Path;
#use Image::Magick;
#use Fcntl ':mode';
#use Attic::Config;
#use URI::QueryParam;
#use Attic::Util;
#use PerlIO::subfile;
use HTTP::Message;
#use HTTP::Date;

use Module::Pluggable search_path => 'Attic::Media', sub_name => 'modules', require => 1, except => 'Attic::Media::Base';

my $log = Log::Log4perl->get_logger();

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
	die 'missing router' unless $self->{router};
	my $modules = $self->{modules} = [];
	foreach my $module (sort {$a->priority > $b->priority} $self->modules()) {
		push @$modules, $module->new(router => $self->{router});
	}
	return $self;
}

sub module {
	my $self = shift;
	my ($media) = @_;
	foreach my $module (@{$self->{modules}}) {
		return $module if $module->accept($media);
	}
	return undef;
}

sub process {
	my $self = shift;
	my ($request, $media) = @_;
	if (my $module = $self->module($media)) {
		return $module->process($request, $media);
	}
	else {
		return [404, ['Content-type', 'text/plain'], ['no media module']];
	}
}

sub serve_file {
	my $class = shift;
	my ($request, $path, $s) = @_;
	if(my $range = $request->env->{HTTP_RANGE}) {
		$range =~ s/^bytes=// or return [416, ['Content-Type' => 'text/plain'], ["Invalid Request Range: $range"]];
		my @ranges = split /\s*,\s*/, $range
			or return [416, ['Content-Type' => 'text/plain'], ["Invalid Request Range: $range"]];
		my $length = $s->[7];
		if (@ranges > 1) {
			# Multiple ranges: http://www.w3.org/Protocols/rfc2616/rfc2616-sec19.html#sec19.2
			open my $fh, "<:raw", $path or return [500, ['Content-type', 'text/plain'], ["can't open $path: $!"]];
			my $msg = HTTP::Message->new([
				'Content-Type' => 'multipart/byteranges',
				'Last-Modified' => HTTP::Date::time2str($s->[9]),
			]);
			my $buf = '';
			foreach my $range (@ranges) {
				my ($start, $end) = $class->parse_range($range, $length)
					or return [416, ['Content-Type' => 'text/plain'], ["Invalid Request Range: $range"]];
				sysseek $fh, $start, 0;
				sysread $fh, $buf, ($end - $start + 1);
				$msg->add_part(HTTP::Message->new([
					'Content-Type' => Plack::MIME->mime_type($path),
					'Content-Range' => "bytes $start-$end/$length"
				], $buf));
			}
			my $headers = $msg->headers;
			return [206, [map {($_ => scalar $headers->header($_))} $headers->header_field_names], [$msg->content]];
		}
		else {
			my ($start, $end) = $class->parse_range($range, $length)
				or return [416, ['Content-Type' => 'text/plain'], ["Invalid Request Range: $range"]];
			open my $fh, "<:raw:subfile(start=$start,end=" . ($end + 1) . ")", $path
				or return [500, ['Content-type', 'text/plain'], ["can't open $path: $!"]];
			Plack::Util::set_io_path($fh, Cwd::realpath($path));
			return [206, [
				'Content-Type' => Plack::MIME->mime_type($path),
				'Content-Range' => "bytes $start-$end/$length",
				'Last-Modified' => HTTP::Date::time2str($s->[9]),
				'Content-Length' => $end + 1 - $start
			], $fh];
		}
	}
	else {
		open my $fh, "<:raw", $path
			or return [500, ['Content-type', 'text/plain'], ["can't open $path: $!"]];
		Plack::Util::set_io_path($fh, Cwd::realpath($path));
		return [ 200, [
			'Content-Type' => Plack::MIME->mime_type($path),
			'Content-Length' => $s->[7],
			'Last-Modified' => HTTP::Date::time2str($s->[9])
		], $fh];		
		return [200, ['Content-type' => 'text/html'], ["follow me: $path"]];
	}
}

sub parse_range {
	my $class = shift;
    my ($range, $length) = @_;
    $range =~ /^(\d*)-(\d*)$/ or return;
    my ($start, $end) = ($1, $2);
    if (length $start and length $end) {
        return if $start > $end; # "200-100"
        return if $end >= $length; # "0-0" on a 0-length file
        return ($start, $end);
    }
    elsif (length $start) {
        return if $start >= $length; # "0-" on a 0-length file
        return ($start, $length - 1);
    }
    elsif (length $end) {
        return if $end > $length;  # "-1" on a 0-length file
        return ($length - $end, $length - 1);
    }
    return;
}

package Attic::Media::Base;

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
	die 'missing router' unless $self->{router};
	return $self;
}

sub accept {
	my $class = shift;
	my ($media) = @_;
	return 0;
}

sub priority { 10 }

sub process {
	die 'not implemented';
}

1;
