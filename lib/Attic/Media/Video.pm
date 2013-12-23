package Attic::Media::Video;

use warnings;
use strict;

use File::Spec;
use Log::Log4perl;
use URI;
use File::Path;
use Attic::Config;
use Attic::Util;
use File::Basename;
use Data::Dumper;
use URI::Escape;

use base 'Attic::Media::Base';

my $log = Log::Log4perl->get_logger();

sub accept {
	my $self = shift;
	my ($media) = @_;
	my ($type, $subtype) = split /\//, $media->{type};
	if ($type eq 'video') {
		return 1;
	}
	return 0;
}

sub process {
	my $self = shift;
	my ($request, $media) = @_;
	my ($path, $s);
	if ($request->uri->query_param('type') and $request->uri->query_param('type') eq 'image') {
		eval {
			($path, $s) = $self->video_thumbnail_cache($media);
		};
		if (my $error = $@) {
			return [500, ['Content-type', 'text/plain'], ["can't load video thumbnail: $error"]];
		}
	}
	else {
		eval {
			($path, $s) = $self->video_cache($media);
		};
		if (my $error = $@) {
			return [500, ['Content-type', 'text/plain'], ["can't load video: $error"]];
		}
	}
	return Attic::Media->serve_file($request, $path, $s);
}

sub video_thumbnail_cache {
	my $self = shift;
	my ($media) = @_;
	my $path = $self->{router}->path(URI->new($media->{uri}));
	my $cache_path_base = uri_unescape($media->{uri});
	$cache_path_base =~ s/^\///; # remove leading slash
	$cache_path_base .= '.jpg';
	my $tmp_cache_path = File::Spec->catfile(Attic::Config->value('cache_dir'), $cache_path_base . '.tmp.jpg');
	my $cache_path = File::Spec->catfile(Attic::Config->value('cache_dir'), $cache_path_base . '.jpg');
	my @cache_s = stat $cache_path or $log->debug("cache $cache_path is missing: $!");
	return ($cache_path, \@cache_s) if @cache_s and $cache_s[9] > $media->{updated};
	File::Path::make_path(dirname($cache_path)) unless -d dirname($cache_path);
	unlink $tmp_cache_path if -f $tmp_cache_path;
	my ($retcode, $stdout, $stderr) = Attic::Util->system_ex([
		'/usr/bin/avconv',
		'-i' => $path,
		'-vframes' => 1,
		'-s' => '320x200',
		$tmp_cache_path], $log);
	die "can't process $path: retcode=$retcode" if $retcode;
	rename $tmp_cache_path, $cache_path or die "can't commit $tmp_cache_path: $!";
	@cache_s = stat $cache_path or die "can't create $cache_path: $!";
	return ($cache_path, \@cache_s);
}

sub video_cache {
	my $self = shift;
	my ($media) = @_;
	my $path = $self->{router}->path(URI->new($media->{uri}));
	my $cache_path_base = uri_unescape($media->{uri});
	$cache_path_base =~ s/^\///; # remove leading slash
	my $tmp_cache_path = File::Spec->catfile(Attic::Config->value('cache_dir'), $cache_path_base. '.tmp.mp4');
	my $cache_path = File::Spec->catfile(Attic::Config->value('cache_dir'), $cache_path_base. '.mp4');
	my @cache_s = stat $cache_path or $log->debug("cache $cache_path is missing: $!");
	return ($cache_path, \@cache_s) if @cache_s and $cache_s[9] > $media->{updated};
	my $start_time = time;
	my $size;
	my $et = Image::ExifTool->new();
	if ($et->ExtractInfo($path)) {
		my $i = $et->GetInfo('ImageWidth', 'ImageHeight');
		if ($i->{ImageWidth} < 854) {
			$size = $i->{ImageWidth} . 'x' . $i->{ImageHeight};
		}
		else {
			my $ratio = 854 / $i->{ImageWidth};
			$size = $i->{ImageWidth} * $ratio . 'x' . $i->{ImageHeight} * $ratio;
		}
	}
	else {
		$size = '854x480';
	}
	File::Path::make_path(dirname($cache_path)) unless -d dirname($cache_path);
	unlink $tmp_cache_path if -f $tmp_cache_path;
	my ($retcode, $stdout, $stderr) = Attic::Util->system_ex([
		'/usr/bin/avconv',
		'-i' => $path,
		'-strict' => 'experimental',
		'-ar' => 44100,
		'-ab' => '128k',
		'-vcodec' => 'libx264',
		'-pix_fmt' => 'yuv420p',
		'-preset' => 'slow',
		'-crf' => 30,
		'-threads' => 0,
		'-s' => $size,
		$tmp_cache_path], $log);
	die "can't process $path: retcode=$retcode" if $retcode;
	rename $tmp_cache_path, $cache_path or die "can't commit $tmp_cache_path: $!";
	@cache_s = stat $cache_path or die "can't create $cache_path: $!";
	$log->info("$cache_path created in " . (time - $start_time) . " second(s)");
	return ($cache_path, \@cache_s);
}

1;
