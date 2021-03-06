package Attic::Directory;

use warnings;
use strict;

use Data::Dumper;
use Log::Log4perl;
use XML::Atom::Feed;

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
	AND i.Width > 800
	AND i.Height > 600
	AND i.Width * 1.2 > i.Height
ORDER BY RANDOM() LIMIT 1
	");
	$sth->execute();
	my $s = [];
	if (my $row = $sth->fetchrow_hashref) {
		my $uri = $row->{Uri};
		my $width = $row->{Width};
		my $height = $row->{Height};
		return [200, ['Content-type', 'application/json'], ["{\"uri\": \"$uri\", \"width\": $width, \"height\": $height}"]];
	}
	else {
		return [404, ['Content-type', 'text/plain'], ['no such image']];
	}
}

sub fetch_recent_entries {
	my $self = shift;
	my ($feed_uri, $count, $offset) = @_;
	$count ||= 10;
	$offset ||= 0;
	my $entries = [];
	my $sth = $self->{router}->{db}->sh->prepare("
SELECT e.Uri, f.Uri AS FeedUri FROM Entry e
JOIN MediaEntry me ON me.EntryId = e.Id
JOIN Media m ON me.MediaId = m.Id
JOIN Feed f ON f.Id = m.FeedId
WHERE e.Uri LIKE '$feed_uri%'
ORDER BY e.Updated DESC
LIMIT ? OFFSET ?
	");
	$sth->execute($count, $offset);
	while (my $row = $sth->fetchrow_hashref) {
		my $entry = $self->{router}->{db}->load_entry($row->{Uri});
		$entry->elem->setAttribute('xml:base', $row->{FeedUri});
		push @$entries, $entry;
	}
	return @$entries ? $entries : undef;
}

sub recent_entries {
	my $self = shift;
	my ($request, $feed, $feed_uri) = @_;
	my $offset = $request->uri->query_param('start') || 0;
	my $size = $request->uri->query_param('size') || 10;
	my $count = 0;
	my $position = 0;
	my $page_uri_list = {};
	while ($count < $size) {
		my $entries = $self->fetch_recent_entries($feed_uri, $size, $position) or last;
		$position += $size;
		foreach my $entry (@$entries) {
			$self->{router}->{page}->populate($entry);
			next unless $entry->category;
			if ($entry->category->term eq 'page') {
				my $response = $self->{router}->{page}->process($request, $entry);			
			}
			if ($entry->content) {
				foreach my $node ($entry->content->elem->findnodes('//script')) { # remove JS
					$node->parentNode->removeChild($node);
				}
				my ($self_link) = grep {$_->rel eq 'self'} $entry->link;
				$page_uri_list->{$self_link->href} = 1;
			}
			elsif ($entry->category->term eq 'page') {
				next;
			}
			if ($entry->category->term eq 'image' and exists $page_uri_list->{$entry->elem->getAttribute('xml:base')}) {
				next;
			}
			if ($offset) {
				$offset--;
			}
			else {
				$feed->add_entry($entry);
				last unless $count++ < $size;
			}
		}
	}
	if (my $parent_link = $self->{router}->{db}->parent_link($feed_uri)) {
		$feed->add_link($parent_link);
	}
	return $feed;
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
	$self->{router}->{th_calc}->set_request($request);
	if ($feed_uri eq $uri) {
		if ($request->uri->query_param('q') and $request->uri->query_param('type') and $request->uri->query_param('type') eq 'image' and $request->uri->query_param('q') eq 'random') {
			return $self->random_image($request, $feed_uri);
		}
		if ($request->uri->query_param('q') and $request->uri->query_param('q') eq 'recent') {
			# recent 10 pages
			my $feed = $self->recent_entries($request, $feed, $feed_uri);
			if ($feed->entries) {
				if ($request->param('type') and $request->param('type') eq 'atom') {
					return [200, ['Content-type', 'text/xml'], [$feed->as_xml]];
				}
				else {
					return [200, ['Content-type', 'text/html'], [Attic::Template->transform('feed', $feed->elem->ownerDocument)]];
				}
			}
			else {
				# nothing recent (or maybe bad start/size parameters)
				return $self->not_found($request, $feed_uri, $feed->title);
			}
		}
		# process directory
		my $index_uri = $self->{router}->{db}->append_entry($feed_uri, 'index');
		if (my $entry = $self->{router}->{db}->load_entry($index_uri)) {
			# display index page
			if (my $parent_link = $self->{router}->{db}->parent_link($uri)) {
				$entry->add_link($parent_link);
			}
			my $response = $self->{router}->{page}->process($request, $entry);
			$self->{router}->{db}->update_feed($uri, $entry->title, $feed->updated);
			$feed->title($entry->title);
			if ($entry->content) {
				return $response;
			}
			else {
				return $self->make_directory_listing($request, $feed, $uri);
			}
		}
		else {
			my (undef, $name) = Attic::Db->pop_name($uri);
			$self->{router}->{db}->update_feed($uri, $name, $feed->updated);
			$feed->title($name);
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

