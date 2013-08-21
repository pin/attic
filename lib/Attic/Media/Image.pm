package Attic::Media::Image;

use warnings;
use strict;

use File::Basename;
use Data::Dumper;
use Log::Log4perl;
use File::Spec;
use URI;
use Image::ExifTool;
use File::Path;
use Image::Magick;
use Attic::Config;
use URI::QueryParam;
use Attic::ThumbnailSize;

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
	my $size = $request->uri->query_param('size');
	if ($size and $size eq 'large') {
		if (my $clientWidth = $request->cookies->{'clientWidth'} and my $clientHeight = $request->cookies->{'clientHeight'}) {
			$clientHeight = $clientHeight - 50 if $clientHeight > 900; # preserve space for header
			$clientWidth = $clientWidth - 40 if $clientWidth > 800; # preserve space for figure left margin
			my ($imageWidth, $imageHeight) = $self->{router}->{db}->load_image($media->{uri});
			if ($imageWidth and $imageHeight) {
				$px = Attic::ThumbnailSize->calculate_px($clientWidth, $clientHeight, $imageWidth, $imageHeight);
			}
		}
	}
	elsif ($size and $size eq 'small') {
		$px = 300;
	}
	$px = $request->uri->query_param('px') if $request->uri->query_param('px');
	if ($px) {
		my $standard_px = Attic::ThumbnailSize->fit_px($px);
		if ($standard_px != $px) {
			my $uri = $request->uri;
			$uri->query_param_delete('size');
			$uri->query_param('px', $standard_px);
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
		$uri->query_param_delete('size');
		return [301, ['Location' => $uri], ["follow $uri"]];
	}
	return Attic::Media->serve_file($request, $path, $s);
}

sub lookup_thumbnail {
	my $self = shift;
	my ($media, $px) = @_;
	my $path = $self->{router}->path(URI->new($media->{uri}));
	my $cache_path = $self->thumbnail_path($media, $px);
	my @cache_s = stat $cache_path;
#	$log->info($media->{updated}, "   ",$cache_s[9]);
	if (@cache_s and $cache_s[9] > $media->{updated}) {
		return ($cache_path, \@cache_s);
	}
	$self->make_thumbnail($path, $media, \@Attic::ThumbnailSize::aspects);
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
	my ($path, $media, $aspects) = @_;
	my $start_time = time;
	my $image = Image::Magick->new();
	$image->Set('memory-limit' => 67108864);
	$image->Set('map-limit' => 134217728);
	if (my $error = $image->Read($path)) {
		die "can't read image " . $path . ": " . $error;
	}
	$image->Strip();
	$image->Set(quality => 85);
	my ($height, $width) = ($image->[0]->Get('height'), $image->[0]->Get('width'));
	my $rotate_degrees = 0;
	if ($et->ExtractInfo($path)) {
		$et->Options(PrintConv => 1);
		if (defined $et->GetValue('Orientation') and $et->GetValue('Orientation') =~ m/Rotate ([0-9]+)/) {
			$rotate_degrees = $1;
		}
		$et->Options(PrintConv => 0);
		my $i = $et->GetInfo('ImageWidth', 'ImageHeight', 'Orientation');
		my ($imageWidth, $imageHeight, $orientation) = ($i->{ImageWidth}, $i->{ImageHeight}, $i->{Orientation});
		if ($orientation) {
			if ($orientation > 4) {
				($imageHeight, $imageWidth) = ($imageWidth, $imageHeight);
				($height, $width) = ($width, $height);
			}
		}
		elsif (my $rotation = $et->GetInfo('Rotation')->{Rotation}) {
			$log->debug($path . ": rotation=$rotation");
			if ($rotation == 270 or $rotation == 90) {
				($imageHeight, $imageWidth) = ($imageWidth, $imageHeight);
			}
		}
		my $description = $et->GetInfo({Group1 => ['XMP-dc']})->{Description};
		$self->{router}->{db}->update_image($media->{uri}, $imageWidth, $imageHeight, $description);
	}
	for my $px (sort {$a < $b} @$aspects) {
		my $cache_path = $self->thumbnail_path($media, $px);
		File::Path::make_path(dirname($cache_path)) unless -d dirname($cache_path);
		my $max_aspect = $image->Get('height') > $image->Get('width') ? $image->Get('height') : $image->Get('width');
		my $size_geometry = 100 * $px / $max_aspect;
		$image->Resize(geometry => $size_geometry . '%');
		if ($rotate_degrees != 0) {
			$image->Rotate(degrees => $rotate_degrees);
			$rotate_degrees = 0;
		}
		my $image = $image->Clone();
		$image->Sharpen(radius => 2);
		if (my $annotation = Attic::Config->value('image_annotation') and $px > 500) {
			my @font_metrics = $image->QueryFontMetrics(text => $annotation, pointsize => 13.5);
			if (my $error = $image->Annotate(text => $annotation, gravity => 'SouthEast', antialias => 1,
					rotate => 270, geometry => '+5+' . ($font_metrics[4] + 7), fill=>'lightgray', pointsize => 13.5)) {
				$log->error('error annotate image: ' . $error);
			}
		}
		$image->Write(filename => $cache_path, interlace => 'Plane');
		$cache_et->ExtractInfo($cache_path);
		$cache_et->SetNewValue('IFD1:Orientation' => 1, Type => 'ValueConv');
		$cache_et->SetNewValue('EXIF:Orientation' => 1, Type => 'ValueConv');
		$cache_et->WriteInfo($cache_path);
	}
	$log->info("$path was indexed in " . (time - $start_time) . ' seconds');
}

sub index {
	shift->make_thumbnail(@_, \@Attic::ThumbnailSize::aspects);
}

sub xmp_param {
	my $self = shift;
	my ($media, $ns, $key, $value) = @_;
	my $path = $self->{router}->path(URI->new($media->{uri}));
	die "cant et" unless $et->ExtractInfo($path);
	if (@_ > 3) {
		$et->SetNewValue('XMP-' . $ns . ':' . $key => $value);
		unless (my $is_success = $et->WriteInfo($path)) {
			my $error = $et->GetValue('Error');
			die "error updating XMP value of $ns:$key at $path: $error";
		}
		return $value;
	}
	else {
		if (my $i = $et->GetInfo({Group1 => ['XMP-' . $ns]})) {
			return $i->{$key};
		}
		return undef;
	}
}

no warnings;

%Image::ExifTool::UserDefined::dpn = (
	GROUPS => {
		0 => 'XMP',
		1 => 'XMP-dpn',
		2 => 'Image'
	},
	NAMESPACE => {
		'dpn' => 'http://dp-net.com/2012/XMP/Bucket'
	},
	Public => {
		Writable => 'boolean'
	},
	Location => {
		Writable => 'string'
	},
	Film => {
		Writable => 'string'
	}
);

%Image::ExifTool::UserDefined = (
		'Image::ExifTool::XMP::Main' => {
		dpn => {
			SubDirectory => {
				TagTable => 'Image::ExifTool::UserDefined::dpn'
			}
		}
	}
);

1;
