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
use URI::QueryParam;
use Attic::Util;
use PerlIO::subfile;
use HTTP::Message;

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
	return 'image/x-dcraw' if $self->path =~ /\.(CRW|NEF|CR2)$/i;
	Plack::MIME->mime_type($self->path) || 'text/plain';
}

sub et {
	my $self = shift;
	my $et = Image::ExifTool->new();
	$et->ExtractInfo($self->path) or return undef;
	return $et;
}

sub xmp_param {
	my $self = shift;
	my ($ns, $key, $value) = @_;
	unless ($self->{et}) {
		my $et = Image::ExifTool->new();
		$et->ExtractInfo($self->path) or return undef;
		$self->{et} = $et;	
	}
	if (@_ > 2) {
		$self->{et}->SetNewValue('XMP-' . $ns . ':' . $key => $value);
		unless (my $is_success = $self->{et}->WriteInfo($self->path)) {
			my $error = $self->{et}->GetValue('Error');
			die "error updating XMP value of $ns:$key at " . $self->path . ": $error";
		}
		delete $self->{et};
		return $value;
	}
	else {
		if (my $i = $self->{et}->GetInfo({Group1 => ['XMP-' . $ns]})) {
			return $i->{$key};
		}
		return undef;
	}
}

my @size_step = (300, 350, 450, 600, 800, 1000, 1200);
sub calculate_px {
	my $self = shift;
	my ($clientWidth, $clientHeight) = @_;
	$log->debug("calculate_px: clientWidth=$clientWidth, clientHeight=$clientHeight");
	my $et = $self->et or return undef;
	$et->Options(PrintConv => 0);
	my $i = $et->GetInfo('ImageWidth', 'ImageHeight', 'Orientation');
	my ($imageWidth, $imageHeight, $orientation) = ($i->{ImageWidth}, $i->{ImageHeight}, $i->{Orientation});
	if ($orientation) {
		$log->debug($self->path . ": orientation=$orientation");
		if ($orientation > 4) {
			($imageHeight, $imageWidth) = ($imageWidth, $imageHeight);
		}
	}
	elsif (my $rotation = $et->GetInfo('Rotation')->{Rotation}) {
		$log->debug($self->path . ": rotation=$rotation");
		if ($rotation == 270 or $rotation == 90) {
			($imageHeight, $imageWidth) = ($imageWidth, $imageHeight);
		}
	}
	$log->debug($self->path . ": imageWidth=$imageWidth, imageHeight=$imageHeight");
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
		$log->debug("image height should be $px");
		if ($imageWidth > $imageHeight) {
			$px = $imageWidth / $imageHeight * $px;
			$log->debug("lanscape image so max aspect should be $px");
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
		$log->debug("image width should be $px");
		if ($imageWidth < $imageHeight) {
			$px = $imageHeight / $imageWidth * $px;
			$log->debug("portrait image so max aspect should be $px");
		}
	}
	$px = int $px;
	$log->debug("px: $px");
	return $px;
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	my ($type, $subtype) = split /\//, $self->content_type;	
	my ($path, $s);
	if ($type eq 'image' and $subtype ne 'gif') {
		my $px;
		if (my $size = $request->uri->query_param('size')) {
			if (my $clientWidth = $request->cookies->{'clientWidth'} and my $clientHeight = $request->cookies->{'clientHeight'}) {
				$clientHeight = $clientHeight - 50 if $clientHeight > 900; # preserve space for header
				$clientWidth = $clientWidth - 40 if $clientWidth > 800; # preserve space for figure left margin
				if (my $c_px = $self->calculate_px($clientWidth, $clientHeight)) {
					$px = $c_px;
				}
			}
			else {
				$px = 800;
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
				($path, $s) = $self->image_cache($px);
			};
			if (my $error = $@) {
				return [500, ['Content-type', 'text/plain'], ["can't load thumbnail: $error"]];
			}
		}
		elsif ($self->uri eq '/2005/usinsk/map-with-track.jpg' or $self->uri eq '/favicon.ico') {
			$path = $self->path;
			my @stat = stat $path or return [500, ['Content-type', 'text/plain'], ["can't open $path: $!"]];
			$s = \@stat;
		}
		else {
			my $uri = $request->uri;
			$uri->query_param('px', 800);
			return [301, ['Location' => $uri], ["follow $uri"]];
		}
	}
	elsif ($type eq 'video') {
		if ($request->uri->query_param('type') and $request->uri->query_param('type') eq 'image') {
			eval {
				($path, $s) = $self->video_thumbnail_cache();
			};
			if (my $error = $@) {
				return [500, ['Content-type', 'text/plain'], ["can't load video thumbnail: $error"]];
			}
		}
		else {
			eval {
				($path, $s) = $self->video_cache();
			};
			if (my $error = $@) {
				return [500, ['Content-type', 'text/plain'], ["can't load video: $error"]];
			}
		}
	}
	else {
		$path = $self->path;
		my @stat = stat $path or return [500, ['Content-type', 'text/plain'], ["can't open $path: $!"]];
		$s = \@stat;
	}
	if(my $range = $env->{HTTP_RANGE}) {
		$range =~ s/^bytes=// or return [416, ['Content-Type' => 'text/plain'], ["Invalid Request Range: $env->{HTTP_RANGE}"]];
		my @ranges = split /\s*,\s*/, $range
			or return [416, ['Content-Type' => 'text/plain'], ["Invalid Request Range: $env->{HTTP_RANGE}"]];
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
				my ($start, $end) = $self->parse_range($range, $length)
					or return [416, ['Content-Type' => 'text/plain'], ["Invalid Request Range: $env->{HTTP_RANGE}"]];
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
			my ($start, $end) = $self->parse_range($range, $length)
				or return [416, ['Content-Type' => 'text/plain'], ["Invalid Request Range: $env->{HTTP_RANGE}"]];
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

sub image_cache {
	my $self = shift;
	my ($px) = @_;
	my $cache_path_base = $self->uri;
	$cache_path_base =~ s/^\///;
	$cache_path_base .= '.' . $px;
	# makes previews in JPG. TODO: add exceptions for PNG and GIF
	my $cache_path = File::Spec->catfile(Attic::Config->value('cache_dir'), $cache_path_base . '.jpg');
	my @cache_s = stat $cache_path or $log->debug("cache $cache_path is missing: $!");
	return ($cache_path, \@cache_s) if @cache_s and $cache_s[9] > $self->modification_time;
	my $start_time = time;
	File::Path::make_path(dirname($cache_path)) unless -d dirname($cache_path);
	my $image = Image::Magick->new();
	my $error = $image->Read($self->path);
	die "can't read image " . $self->path . ": " . $error if $error; 
	$image->Strip();
	$image->Set(interlace => 'Plane');
	$image->Set(quality => 85);
	my ($height, $width) = ($image->[0]->Get('height'), $image->[0]->Get('width'));
	my $aspect_ratio = $px / ($height > $width ? $height : $width);
	$image->Resize(height => $height * $aspect_ratio, width => $aspect_ratio * $width);
	#$image->UnsharpMask(amount => 100, radius => 5, threshold => 1);
	$image->Sharpen(radius => 2);
	if ($et->ExtractInfo($self->path)) {
		if (defined $et->GetValue('Orientation') and $et->GetValue('Orientation') =~ m/Rotate ([0-9]+)/) {
			$image->Rotate(degrees => $1);
		}
	}
	$image->Write(filename => $cache_path);
	$cache_et->ExtractInfo($cache_path);
	$cache_et->SetNewValue('IFD1:Orientation' => 1, Type => 'ValueConv');
	$cache_et->SetNewValue('EXIF:Orientation' => 1, Type => 'ValueConv');
	$cache_et->WriteInfo($cache_path);
	$log->info("$cache_path was generated in " . (time - $start_time) . ' second(s)');
	@cache_s = stat $cache_path or die "can't create $cache_path: $!";
	return ($cache_path, \@cache_s);
}

sub video_thumbnail_cache {
	my $self = shift;
	my $cache_path_base = $self->uri;
	$cache_path_base =~ s/^\///;
	$cache_path_base .= '.jpg';
	my $tmp_cache_path = File::Spec->catfile(Attic::Config->value('cache_dir'), $cache_path_base . '.tmp.jpg');
	my $cache_path = File::Spec->catfile(Attic::Config->value('cache_dir'), $cache_path_base . '.jpg');
	my @cache_s = stat $cache_path or $log->debug("cache $cache_path is missing: $!");
	return ($cache_path, \@cache_s) if @cache_s and $cache_s[9] > $self->modification_time;
	File::Path::make_path(dirname($cache_path)) unless -d dirname($cache_path);
	unlink $tmp_cache_path if -f $tmp_cache_path;
	my ($retcode, $stdout, $stderr) = Attic::Util->system_ex('/usr/bin/ffmpeg -i ' . $self->path
		. ' -vframes 1 -s 320x200 ' . $tmp_cache_path, $log);
	die "can't process " . $self->path . ": retcode=$retcode" if $retcode;
	rename $tmp_cache_path, $cache_path or die "can't commit $tmp_cache_path: $!";
	@cache_s = stat $cache_path or die "can't create $cache_path: $!";
	return ($cache_path, \@cache_s);
}

sub video_cache {
	my $self = shift;
	my $cache_path_base = $self->uri;
	$cache_path_base =~ s/^\///;
	my $tmp_cache_path = File::Spec->catfile(Attic::Config->value('cache_dir'), $cache_path_base. '.tmp.mp4');
	my $cache_path = File::Spec->catfile(Attic::Config->value('cache_dir'), $cache_path_base. '.mp4');
	my @cache_s = stat $cache_path or $log->debug("cache $cache_path is missing: $!");
	return ($cache_path, \@cache_s) if @cache_s and $cache_s[9] > $self->modification_time;
	my $start_time = time;
	File::Path::make_path(dirname($cache_path)) unless -d dirname($cache_path);
	unlink $tmp_cache_path if -f $tmp_cache_path;
	my ($retcode, $stdout, $stderr) = Attic::Util->system_ex('/usr/bin/ffmpeg -i ' . $self->path
		. ' -acodec libfaac -ab 128k -vcodec libx264 -pix_fmt yuv420p -preset slow -crf 30 -threads 0 -s 854x480 '
			. $tmp_cache_path, $log);
	die "can't process " . $self->path . ": retcode=$retcode" if $retcode;
	rename $tmp_cache_path, $cache_path or die "can't commit $tmp_cache_path: $!";
	@cache_s = stat $cache_path or die "can't create $cache_path: $!";
	$log->info("$cache_path created in " . time - $start_time . " second(s)");
	return ($cache_path, \@cache_s);
}

1;
