package Attic::Directory;

use strict;
use warnings;

use base 'Plack::Component';

use Plack::Request;
use Data::Dumper;
use Log::Log4perl;
use File::Spec;
use Attic::File;
use Fcntl ':mode';
use Attic::Hub;
use XML::Atom::Feed; $XML::Atom::DefaultVersion = '1.0';
use URI;
use XML::Atom::Ext::Inline;

my $log = Log::Log4perl->get_logger();

sub prepare_app {
	my $self = shift;
	$log->debug("preparing directory: " . $self->path);
	$self->{hubs} = {}; $self->{files} = {}; $self->{directories} = {};
	opendir my $dh, $self->path or die "can't open " . $self->path . ": $!";
	while (my $f = readdir $dh) {
		next if $f =~ /^\./;
		my $path = File::Spec->catfile($self->path, $f);
		my @s = lstat $path or do {
			$log->debug("can't stat $path: $!");
			return;
		};
		next unless my $is_other_readable = $s[2] & S_IROTH;
		if (S_ISREG($s[2])) {
			my $file = $self->{files}->{$f} = Attic::File->new(dir => $self, name => $f, status => \@s);
			my @t = split /\./, $f;
			pop @t;
			while (@t) {
				my $h = join '.', @t;
				unless (exists $self->{hubs}->{$h}) {
					$self->{hubs}->{$h} = Attic::Hub->new(name => $h, dir => $self);
				}
				$self->{hubs}->{$h}->add_file($file);
				pop @t;
			}
		}
		elsif (S_ISDIR($s[2])) {
			my $dir_uri = URI->new($self->{uri});
			my @dir_s = $dir_uri->path_segments;
			pop @dir_s if $dir_s[$#dir_s] eq '';
			$dir_uri->path_segments(@dir_s, $f, '');
			$self->{directories}->{$f} = $self->{router}->directory($dir_uri, \@s);
		}
	}
	closedir $dh;
	foreach my $hub_name (keys %{$self->{hubs}}) {
		$self->hub_app($hub_name);
	}
	foreach my $dir (values %{$self->{directories}}) {
		$dir->app;
	}
	$log->info("$self->{uri} directory init complete");
}

sub uri {
	shift->{uri};
}

sub path {
	my $self = shift;
	return $self->{router}->path($self->{uri});
}

sub pop_name {
	my $class = shift;
	my ($uri) = @_;
	my $parent_uri = URI->new($uri);
	return undef if $uri->path eq '/';
	my @segments = grep {$_ ne '.' and $_ ne '..'} $uri->path_segments;
	my $name = pop @segments;
	$name = pop @segments unless (length $name); # in case we already have slash at the end
	$parent_uri->path_segments(@segments, '');
	return ($parent_uri, $name);
}

sub title {
	my $self = shift;
	if (exists $self->{hubs}->{'index'}) {
		return $self->{hubs}->{'index'}->title;
	}
	else {
		return $self->name;
	}
}

sub name {
	my $self = shift;
	my ($a, $name) = __PACKAGE__->pop_name($self->{uri});
	return $name;
}

sub hub_app {
	my $self = shift;
	my ($name) = @_;
	return $self->{hub_app}->{$name} if exists $self->{hub_app}->{$name};
	if (exists $self->{hubs}->{$name}) {
		return $self->{hub_app}->{$name} = $self->{hubs}->{$name}->to_app;
	}
	return undef;
}

sub file_app {
	my $self = shift;
	my ($name) = @_;
	return $self->{file_app}->{$name} if exists $self->{file_app}->{$name};
	if (exists $self->{files}->{$name}) {
		return $self->{file_app}->{$name} = $self->{files}->{$name}->to_app;
	}
	return undef;
}

sub modification_time {
	shift->{status}->[9];
}

sub populate_entry {
	my $self = shift;
	my ($entry, $request) = @_;
	my $category = XML::Atom::Category->new();
	$category->term('directory');
	$category->scheme('http://dp-net.com/2009/Atom/EntryType');
	$entry->category($category);
}

sub populate_siblings {
	my $self = shift;
	my ($entry, $name) = @_;
	
	return if $name eq 'index';

    my $link = XML::Atom::Link->new();
    $link->rel('index');
    $link->title($self->name);
    $link->type('text/html');
    $link->href($self->uri);
    $entry->add_link($link);

	if (exists $self->{hubs}->{$name}) {
		my $previous_name;
		foreach my $e (sort {$a->modification_time <=> $b->modification_time} values %{$self->{hubs}}) {
			if (defined $previous_name and $previous_name eq $name) {
				my $link = XML::Atom::Link->new();
				$link->rel('next');
				$link->title($e->name);
				$link->type('text/html');
				$link->href($e->uri);
				$entry->add_link($link);
				last;
			}
			if ($previous_name and $e->name eq $name) {
				my $link = XML::Atom::Link->new();
				$link->rel('previous');
				$link->title($self->{hubs}->{$previous_name}->name);
				$link->type('text/html');
				$link->href($self->{hubs}->{$previous_name}->uri);
				$entry->add_link($link);
			}
			$previous_name = $e->name;
		}
	}
}

sub parent_link {
	my $self = shift;
	my $uri = $self->uri;
	my ($parent_uri, $name) = $self->pop_name($uri);
	return undef unless $parent_uri;
	my $parent_dir = $self->{router}->directory($parent_uri);
	$parent_dir->app; # force reading all directories
	my $inline = XML::Atom::Ext::Inline->new();
	my $feed = XML::Atom::Feed->new();
	if (my $parent_link = $parent_dir->parent_link) {
		$feed->add_link($parent_link);
	}
	$feed->title($parent_dir->title);
	{
		my $link = XML::Atom::Link->new();
		$link->href($parent_dir->uri);
		$link->rel('self');
		$link->type('text/html');
		$feed->add_link($link);
	}
	$inline->atom($feed);
	my $link = XML::Atom::Link->new();
	$link->href($parent_uri);
	$link->rel('up');
	$link->type('text/html');
	$link->inline($inline);
	return $link;
}

sub app {
	my $self = shift;
	return $self->{app} if exists $self->{app};
	return $self->{app} = $self->to_app;
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	if ($request->uri->path eq $self->{uri}->path) {
		unless ($request->uri->path =~ /\/$/) {
			# redirect to URI with / at the end 
			my $uri = $request->uri;
			$uri->path($uri->path . '/');
			return [301, ['Location' => $uri], ["follow $uri"]];
		}
		if (my $hub_app = $self->hub_app('index') and $self->{hubs}->{'index'}->{impl}->{body}) {
			# show index page
			$log->debug("directory request to " . $request->uri->path . " goes to index");
			return $hub_app->($env);
		}
		else {
			# show directory contents
			my $feed = XML::Atom::Feed->new();
			$feed->title($self->title);
			my @entries = (values %{$self->{hubs}}, values %{$self->{directories}});
			foreach my $e (sort {$a->modification_time <=> $b->modification_time} @entries) {
				my $entry = XML::Atom::Entry->new();
				$entry->title($e->title);
				
				my ($day, $mon, $year) = (localtime $e->modification_time)[3..5];
				$entry->updated(sprintf "%04d-%02d-%02d", 1900 + $year, 1 + $mon, $day);

				my $link = XML::Atom::Link->new();
				$link->rel('self');
				$link->type('text/html');
				$link->href($e->uri);
				$entry->add_link($link);

				$e->populate_entry($entry, $env);
				$feed->add_entry($entry);
			}
			if (my $parent_link = $self->parent_link) {
				$feed->add_link($parent_link);
			}
			if ($request->param('type') and $request->param('type') eq 'atom') {
				return [200, ['Content-type', 'text/xml'], [$feed->as_xml]];
			}
			else {
				return [200, ['Content-type', 'text/html'], [Attic::Template->transform('directory', $feed->elem->ownerDocument)]];
			}
		}
	}
	else {
		my ($parent_uri, $name) = __PACKAGE__->pop_name($request->uri);
		if ($parent_uri and $parent_uri->path eq $self->{uri}->path) {
			# show hub or serve file
			if (my $hub_app = $self->hub_app($name)) {
				return $hub_app->($env);
			}
			elsif (my $file_app = $self->file_app($name)) {
				return $file_app->($env);
			}
		}
	}
	# the only thing left is to show 404
	my $entry = XML::Atom::Entry->new();
	my $inline = XML::Atom::Ext::Inline->new();
	my $feed = XML::Atom::Feed->new();
	if (my $parent_link = $self->parent_link) {
		$feed->add_link($parent_link);
	}
	$feed->title($self->title);
	$inline->atom($feed);
	my $link = XML::Atom::Link->new();
	$link->href($self->uri);
	$link->rel('up');
	$link->type('text/html');
	$link->inline($inline);
	$entry->add_link($link);
	if ($request->param('type') and $request->param('type') eq 'atom') {
		return [404, ['Content-type', 'text/xml'], [$entry->as_xml]];
	}
	else {
		return [404, ['Content-type', 'text/html'], [Attic::Template->transform('not-found', $entry->elem->ownerDocument)]];
	}
}

1;
