package Attic::Router;

use warnings;
use strict;

use base 'Plack::Component';

use Plack::Request;
use Data::Dumper;
use Log::Log4perl;
use File::Spec;
use Attic::Directory;
use URI;
use Fcntl ':mode';
use Attic::Config;
use Attic::Db;
use Attic::Media;
use Attic::Page;

my $log = Log::Log4perl->get_logger();

sub prepare_app {
	my $self = shift;
	my $version = 10;
	$self->{db} = Attic::Db->new(path => File::Spec->catfile(Attic::Config->value('cache_dir'), 'db.' . $version . '.sqlite3'));
	$self->{page} = Attic::Page->new(router => $self);
	$self->{directory} = Attic::Directory->new(router => $self);
	$self->{media} = Attic::Media->new(router => $self);
}

sub path {
	my $self = shift;
	my ($uri) = @_;
	my @segments = File::Spec->no_upwards(grep {$_} $uri->path_segments);
	my $path = File::Spec->catdir($self->{documents_dir}, @segments);
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	my $uri = URI->new($request->uri->path);
	while ($uri) {
		if (my $feed = $self->discover_feed($uri)) {
			return $self->{directory}->process($request, $feed);
		}
		($uri, undef) = Attic::Db->pop_name($uri);
	}
	return [500, ['Content-type', 'text/plain'], ['shit happens']];
}

sub discover_feed {
	my $self = shift;
	my ($uri) = @_;
	my $path = $self->path($uri);
	my @s = stat $path;
	return undef unless @s and my $is_other_readable = $s[2] & S_IROTH;
	return undef if S_ISREG($s[2]);
	return undef unless S_ISDIR($s[2]) and $uri =~ /\/$/;
	if (my $feed = $self->{db}->load_feed($uri)) {
		warn $feed->{updated_ts};
		warn $s[9];
		return $feed if $feed->{updated_ts} == $s[9];
	}
	opendir my $dh, $path or die "can't open $path: $!";
	my $dt = Attic::Db::UpdateTransaction->new(dbh => $self->{db}->sh, uri => $uri);
	while (my $f = readdir $dh) {
		next if $f =~ /^\./;
		my $f_path = File::Spec->catfile($path, $f);
		my @f_s = lstat $f_path or do {
			$log->debug("can't stat $f_path: $!");
			next;
		};
		next unless my $is_other_readable = $f_s[2] & S_IROTH;
		my $f_uri = URI->new($uri);
		my @f_segments = $f_uri->path_segments;
		pop @f_segments if $f_segments[$#f_segments] eq '';
		if (S_ISREG($f_s[2])) {
			$f_uri->path_segments(@f_segments, $f);
			my $content_type;
			if ($f_path =~ /\.(CRW|NEF|CR2)$/i) {
				$content_type = 'image/x-dcraw' 
			}
			else {
				$content_type = Plack::MIME->mime_type($f_path) || 'text/plain';	
			}
			$dt->process_media($f_uri, $f_s[9], $content_type);
		}
		elsif (S_ISDIR($f_s[2])) {
			$f_uri->path_segments(@f_segments, $f, '');
			$dt->process_feed($f_uri, $f_s[9]);
		}
	}
	$dt->commit($s[9]);
	closedir $dh;
	return $self->{db}->load_feed($uri);
}

1;
