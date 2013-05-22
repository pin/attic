package Attic::Directory;

use warnings;
use strict;

use Data::Dumper;
use Log::Log4perl;

my $log = Log::Log4perl->get_logger();

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
	die 'missing router' unless $self->{router};
	return $self;
}

sub make_directory_listing {
	my $self = shift;
	my ($request, $feed, $uri) = @_;
	my $f_list = $self->{router}->{db}->list_feed_feeds($uri);
	my $e_list = $self->{router}->{db}->list_feed_entries($uri);
	foreach my $entry (@$f_list, @$e_list) {
		$self->{router}->{page}->populate($entry);
		$feed->add_entry($entry);
	}
	if (my $parent_link = $self->{router}->{db}->parent_link($uri)) {
		$feed->add_link($parent_link);
	}
	if ($request->param('type') and $request->param('type') eq 'atom') {
		return [200, ['Content-type', 'text/xml'], [$feed->as_xml]];
	}
	else {
		return [200, ['Content-type', 'text/html'], [Attic::Template->transform('directory', $feed->elem->ownerDocument)]];
	}
}

sub random_image {
	my $self = shift;
	my ($request, $feed_uri) = @_;
	my $sth = $self->{router}->{db}->sh->prepare("
SELECT m.Uri, i.Width, i.Height FROM Image i
JOIN Media m ON i.MediaId = m.Id
WHERE m.Uri LIKE '$feed_uri%'
	");
	$sth->execute();
	my $s = [];
	while (my $row = $sth->fetchrow_hashref) {
		my $w = $row->{Width};
		my $h = $row->{Height};
		if ($w > $h and $w > 800 and $h > 600) {
			push @$s, $row->{Uri}; 
		}
	}
	my $n = scalar @$s;
	my $uri = $s->[int(rand($n))];
	my $media = $self->{router}->{db}->load_media($uri);
	return $self->{router}->{media}->process($request, $media);
}

sub process {
	my $self = shift;
	my ($request, $feed) = @_;
	my $uri = URI->new($request->uri->path);
	my ($self_link) = grep {$_->rel eq 'self'} $feed->link;
	my $feed_uri = URI->new($self_link->href);
	if (my $media = $self->{router}->{db}->load_media($uri)) {
		return $self->{router}->{media}->process($request, $media);
	}
	elsif ($feed_uri eq $uri) {
		if ($request->uri->query_param('q') and $request->uri->query_param('type') and $request->uri->query_param('type') eq 'image' and $request->uri->query_param('q') eq 'random') {
			# random picture
			return $self->random_image($request, $feed_uri);
		}
		# process directory
		my $index_uri = $self->{router}->{db}->append_entry($feed_uri, 'index');
		if (my $entry = $self->{router}->{db}->load_entry($index_uri)) {
			# display index page
			if (my $parent_link = $self->{router}->{db}->parent_link($uri)) {
				$entry->add_link($parent_link);
			}
			my $response = $self->{router}->{page}->process($request, $entry);
			$self->{router}->{db}->update_feed($uri, $entry->title, $entry->updated);
			if ($entry->content) {
				return $response;
			}
			else {
				return $self->make_directory_listing($request, $feed, $uri);
			}
		}
		else {
			return $self->make_directory_listing($request, $feed, $uri);
		}
	}
	elsif (my $entry = $self->{router}->{db}->load_entry($uri)) {
		# process page
		foreach my $link ($self->{router}->{db}->sibling_links($uri)) {
			$entry->add_link($link) if $link;
		}
		if (my $parent_link = $self->{router}->{db}->parent_link($uri)) {
			$entry->add_link($parent_link);
		}
		return $self->{router}->{page}->process($request, $entry);
	}
	elsif ($uri !~ /\/$/) {
		# redirect to URI with / at the end 
		$uri->path($uri->path . '/');
		if ($self->{router}->{db}->load_feed($uri)) {
			my $f_uri = $request->uri;
			$f_uri->path($uri->path);
			return [301, ['Location' => $f_uri], ["follow $f_uri"]];
		}
	}
	# the only option left is to give up and show 404
	return $self->not_found($request, $feed_uri, $feed->title);
}

sub not_found {
	my $self = shift;
	my ($request, $uri, $title) = @_;
	my $entry = XML::Atom::Entry->new();
	my $inline = XML::Atom::Ext::Inline->new();
	my $feed = XML::Atom::Feed->new();
	if (my $parent_link = $self->{router}->{db}->parent_link($uri)) {
		$feed->add_link($parent_link);
	}
	$feed->title($title);
	$inline->atom($feed);
	my $link = XML::Atom::Link->new();
	$link->href($uri);
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

