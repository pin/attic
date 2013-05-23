package Attic::Media::Image;

use warnings;
use strict;

use File::Basename;

use Data::Dumper;
use Log::Log4perl;
use File::Spec;
#use Plack::MIME;
#use Plack::Util;
use URI;
use Image::ExifTool;
use File::Path;
use Image::Magick;
#use Fcntl ':mode';
#use Attic::Config;
use URI::QueryParam;
#use Attic::Util;
#use PerlIO::subfile;
#use HTTP::Message;

use base 'Attic::Media::Base';

my $log = Log::Log4perl->get_logger();

sub accept {
	my $self = shift;
	my ($media) = @_;
	return 0 if $media->{uri} =~ /map-with-track\.jpg$/; # HACK
	my ($type, $subtype) = split /\//, $media->{type};
	if ($type eq 'image' and $subtype ne 'gif' and $subtype ne 'vnd.microsoft.icon') {
		return 1;
	}
	return 0;
}

sub process {
	my $self = shift;
	my ($request, $media) = @_;
	my ($path, $s);
	my $px;
	if (my $size = $request->uri->query_param('size')) {
		if (my $clientWidth = $request->cookies->{'clientWidth'} and my $clientHeight = $request->cookies->{'clientHeight'}) {
			$clientHeight = $clientHeight - 50 if $clientHeight > 900; # preserve space for header
			$clientWidth = $clientWidth - 40 if $clientWidth > 800; # preserve space for figure left margin
			my ($imageWidth, $imageHeight) = $self->{router}->{db}->load_image($media->{uri});
			if ($imageWidth and $imageHeight) {
				$px = $self->calculate_px($clientWidth, $clientHeight, $imageWidth, $imageHeight);
			}
		}
	}
	$px = $request->uri->query_param('px') if $request->uri->query_param('px');
	if ($px) {
		if ($px > 1200) {
			my $uri = $request->uri;
			$uri->query_param('px', 1200);
			return [301, ['Location' => $uri], ["follow $uri"]];
		}
		eval {
			($path, $s) = $self->lookup_thumbnail($media, $px);
		};
		if (my $error = $@) {
			return [500, ['Content-type', 'text/plain'], ["can't load thumbnail: $error"]];
		}
	}
	else {
		my $uri = $request->uri;
		$uri->query_param('px', 800);
		return [301, ['Location' => $uri], ["follow $uri"]];
	}
	return Attic::Media->serve_file($request, $path, $s);
}

my @size_step = (300, 350, 450, 600, 800, 1000, 1200);
sub calculate_px {
	my $class = shift;
	my ($clientWidth, $clientHeight, $imageWidth, $imageHeight) = @_;
	my $px = $size_step[0];
	if ($clientWidth / $clientHeight > $imageWidth / $imageHeight) {
		foreach my $s (@size_step) {
			if ($clientHeight > $s) {
				$px = $s;
			}
			else {
				last;
			}
		}
		if ($imageWidth > $imageHeight) {
			$px = $imageWidth / $imageHeight * $px;
		}
	}
	else {
		foreach my $s (@size_step) {
			if ($clientWidth > $s) {
				$px = $s;
			}
			else {
				last;
			}
		}
		if ($imageWidth < $imageHeight) {
			$px = $imageHeight / $imageWidth * $px;
		}
	}
	$px = int $px;
	return $px;
}

sub lookup_thumbnail {
	my $self = shift;
	my ($media, $px) = @_;
	my $path = $self->{router}->path(URI->new($media->{uri}));
	my $cache_path = $self->thumbnail_path($media, $px);
	my @cache_s = stat $cache_path;
	if (@cache_s and $cache_s[9] > $media->{updated}) {
		return ($cache_path, \@cache_s);
	}
	$self->make_thumbnail($path, $media, $px);
#	$self->make_thumbnail($path, $media, 1000) if $px == 300;
#	$self->make_thumbnail($path, $media, 1200) if $px == 800;
	@cache_s = stat $cache_path or die "can't make $cache_path: $!";
	return ($cache_path, \@cache_s);
}

sub thumbnail_path {
	my $class = shift;
	my ($media, $px) = @_;
	my $path_base = $media->{uri};
	$path_base =~ s/^\///;
	$path_base .= '.' . $px;
	my $path = File::Spec->catfile(Attic::Config->value('cache_dir'), $path_base . '.jpg'); # makes previews in JPG. TODO: add exceptions for PNG and GIF
	return $path;
}

my $et = Image::ExifTool->new();
my $cache_et = Image::ExifTool->new();

sub make_thumbnail {
	my $self = shift;
	my ($path, $media, $px) = @_;
	my $cache_path = $self->thumbnail_path($media, $px);
	my $start_time = time;
	File::Path::make_path(dirname($cache_path)) unless -d dirname($cache_path);
	my $image = Image::Magick->new();
	$image->Set('memory-limit' => 67108864);
	$image->Set('map-limit' => 134217728);
	my $error = $image->Read($path);
	die "can't read image " . $path . ": " . $error if $error; 
	$image->Strip();
	$image->Set(interlace => 'Plane');
	$image->Set(quality => 85);
	my ($height, $width) = ($image->[0]->Get('height'), $image->[0]->Get('width'));
	my $aspect_ratio = $px / ($height > $width ? $height : $width);
	$image->Resize(height => $height * $aspect_ratio, width => $aspect_ratio * $width);
	$image->Sharpen(radius => 2);
	if ($et->ExtractInfo($path)) {
		$et->Options(PrintConv => 1);
		if (defined $et->GetValue('Orientation') and $et->GetValue('Orientation') =~ m/Rotate ([0-9]+)/) {
			$image->Rotate(degrees => $1);
		}
		$et->Options(PrintConv => 0);
		my $i = $et->GetInfo('ImageWidth', 'ImageHeight', 'Orientation');
		my ($imageWidth, $imageHeight, $orientation) = ($i->{ImageWidth}, $i->{ImageHeight}, $i->{Orientation});
		if ($orientation) {
			if ($orientation > 4) {
				($imageHeight, $imageWidth) = ($imageWidth, $imageHeight);
			}
		}
		elsif (my $rotation = $et->GetInfo('Rotation')->{Rotation}) {
			$log->debug($path . ": rotation=$rotation");
			if ($rotation == 270 or $rotation == 90) {
				($imageHeight, $imageWidth) = ($imageWidth, $imageHeight);
			}
		}
		$self->{router}->{db}->update_image($media->{uri}, $imageWidth, $imageHeight);
	}
	$image->Write(filename => $cache_path);
	$cache_et->ExtractInfo($cache_path);
	$cache_et->SetNewValue('IFD1:Orientation' => 1, Type => 'ValueConv');
	$cache_et->SetNewValue('EXIF:Orientation' => 1, Type => 'ValueConv');
	$cache_et->WriteInfo($cache_path);
	$log->info("$cache_path was generated in " . (time - $start_time) . ' second(s)');
}

1;
