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
use Image::ExifTool;
use File::Path;
use File::Basename;
use Image::Magick;
use Fcntl ':mode';
use Attic::Config;

my $log = Log::Log4perl->get_logger();
my $et = Image::ExifTool->new();
my $cache_et = Image::ExifTool->new();

sub prepare_app {
	my $self = shift;
	$log->info($self->uri . " file loaded");
}

sub path {
	my $self = shift;
	File::Spec->catfile($self->{dir}->path, $self->{name});
}

sub modification_time {
	shift->{status}->[9];
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
	return 'image/x-dcraw' if uc $self->path =~ /\.(CRW|NEF|CR2)$/i;
	Plack::MIME->mime_type($self->path) || 'text/plain';
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	if (my $px = $request->uri->query_param('px')) {
		my $cache_path = File::Spec->catfile(Attic::Config->value('cache_dir'), $px, $self->{name});
		$cache_path =~ s/\.[a-z]+$/\.jpg/i; # makes previews in JPG. TODO: add exceptions for PNG and GIF
		my @cache_s = stat $cache_path or $log->debug("$cache_path: $!");
		unless (@cache_s and $cache_s[9] > $self->modification_time) {
			my $start_time = time;
			unless (-d dirname($cache_path)) {
				File::Path::make_path(dirname($cache_path));	
			}
			my $image = Image::Magick->new();
			my $x = $image->Read($self->path);
			return [ 404, ['Content-type', 'text/plain'], "can't read image: $x"] if $x; 
			my ($height, $width) = ($image->[0]->Get('height'), $image->[0]->Get('width'));
			my $aspect_ratio = $px / ($height > $width ? $height : $width);
			$image->Resize(height => $height * $aspect_ratio, width => $aspect_ratio * $width);
			#$image->UnsharpMask(amount => 100, radius => 5, threshold => 1);
			$image->Sharpen(radius => 2);
			
			if ($et->ExtractInfo($self->path)) {
				if (defined $et->GetValue('Orientation') and $et->GetValue('Orientation') =~ m/Rotate ([0-9]+)/) {
					$image->Rotate(degrees=>$1);
				}
			}
			$image->Write(filename => $cache_path);
			$cache_et->ExtractInfo($cache_path);
			$cache_et->SetNewValue('IFD1:Orientation' => 1, Type => 'ValueConv');
			$cache_et->SetNewValue('EXIF:Orientation' => 1, Type => 'ValueConv');
			$cache_et->WriteInfo($cache_path);
			$log->info($request->uri . " was generated in " . (time - $start_time) . ' second(s)')
		}
		@cache_s = stat $cache_path or return [500, ['Content-type', 'text/plain'], ["failed to create $cache_path: $!"]];
		if (S_ISREG($cache_s[2])) {
			open my $fh, "<:raw", $cache_path
				or return [ 403, ['Content-type', 'text/plain'], ["can't open $cache_path: $!"]];
			Plack::Util::set_io_path($fh, Cwd::realpath($cache_path));
			return [ 200, [
				'Content-Type'   => Plack::MIME->mime_type($cache_path),
				'Content-Length' => $cache_s[7],
				'Last-Modified'  => HTTP::Date::time2str($cache_s[9])
			], $fh, ];
		}
	}
	open my $fh, "<:raw", $self->path or return [403, ['Content-type', 'text/plain'], ["can't open " . $self->path . ": $! "]];
	Plack::Util::set_io_path($fh, Cwd::realpath($self->path));
	return [200, [
		'Content-Type' => $self->content_type,
		'Last-Modified' => HTTP::Date::time2str($self->modification_time),
		'Content-Length' => $self->{status}->[7]
	], $fh, ];
}

1;
