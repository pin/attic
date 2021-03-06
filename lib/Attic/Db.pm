package Attic::Db;

use warnings;
use strict;

use Log::Log4perl;
use DBI;
use XML::Atom; $XML::Atom::DefaultVersion = '1.0';
use XML::Atom::Ext::Inline;

my $log = Log::Log4perl->get_logger();
my $cache = {};

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
	die 'missing path' unless $self->{path};
	$self->install unless -f $self->{path};
	return $self;
}

sub install {
	my $self = shift;
	my $dbh = $self->h;
	$dbh->do('BEGIN TRANSACTION');
	$dbh->do('
CREATE TABLE Feed (
Id INTEGER PRIMARY KEY AUTOINCREMENT,
FeedId INTEGER,
Title TEXT,
Updated DATETIME,
Syncronized DATETIME,
Uri TEXT NOT NULL UNIQUE,
FOREIGN KEY(FeedId) REFERENCES Feed(Id) ON DELETE CASCADE
	)');
	$dbh->do('
INSERT INTO Feed (Uri) VALUES ("/")
	');
	$dbh->do('
CREATE TABLE Media (
Id INTEGER PRIMARY KEY AUTOINCREMENT,
FeedId INTEGER NOT NULL,
Title TEXT,
Updated DATETIME,
Uri TEXT NOT NULL UNIQUE,
Type TEXT,
FOREIGN KEY(FeedId) REFERENCES Feed(Id) ON DELETE CASCADE
	)');
	$dbh->do('
CREATE TABLE Entry (
Id INTEGER PRIMARY KEY AUTOINCREMENT,
Title TEXT,
Updated DATETIME,
Uri TEXT NOT NULL UNIQUE
	)');
	$dbh->do('
CREATE TABLE MediaEntry (
Id INTEGER PRIMARY KEY AUTOINCREMENT,
MediaId INTEGER NOT NULL,
EntryId INTEGER NOT NULL,
FOREIGN KEY(MediaId) REFERENCES Media(Id) ON DELETE CASCADE,
FOREIGN KEY(EntryId) REFERENCES Entry(Id) ON DELETE CASCADE
	)');
	$dbh->do('
CREATE TABLE Image (
Id INTEGER PRIMARY KEY AUTOINCREMENT,
MediaId TEXT NOT NULL UNIQUE,
Width INTEGER,
Height INTEGER,
Description TEXT,
FOREIGN KEY(MediaId) REFERENCES Media(Id) ON DELETE CASCADE
	)');
	$dbh->do('
CREATE TABLE Text (
Id INTEGER PRIMARY KEY AUTOINCREMENT,
MediaId TEXT NOT NULL UNIQUE,
FOREIGN KEY(MediaId) REFERENCES Media(Id) ON DELETE CASCADE
	)');
	$dbh->do('COMMIT TRANSACTION');
	
	$dbh->do('
CREATE TRIGGER DeleteDirectoryContents BEFORE DELETE ON Feed
BEGIN
	DELETE FROM Entry 
	WHERE Id IN (
		SELECT EntryId FROM MediaEntry me
		JOIN Media m ON me.MediaId = m.Id
		WHERE m.FeedId = OLD.Id
	);
	DELETE FROM Media WHERE FeedId = OLD.Id;
END
	');

	$log->info("database at $self->{path} initialized");
}

sub h {
	my $self = shift;
	my $dbh = DBI->connect("dbi:SQLite:dbname=$self->{path}", undef, undef, {RaiseError => 1});
	$log->debug("database at $self->{path} connected");
	$dbh->do('PRAGMA synchronous=OFF');
	$dbh->do('PRAGMA foreign_keys=ON');
	return $dbh;
}

sub sh {
	my $self = shift;
	if (exists $self->{shared_dbh}) {
		return $self->{shared_dbh};
	}
	else {
		return $self->{shared_dbh} = $self->h;
	}
}

sub load_feed {
	my $class = shift;
	my ($uri) = @_;
	my $sth = $class->sh->prepare("
SELECT Id, Title, Updated, strftime('%s', Updated) AS UpdatedTS, strftime('%s', Syncronized) AS Syncronized FROM Feed
WHERE Uri = ?
	");
	$sth->execute($uri);
	my $row = $sth->fetchrow_hashref or return undef;
	my $feed = XML::Atom::Feed->new();
	$feed->id($row->{Id});
	if (my $title = $row->{Title}) {
		$feed->title($title);
	}
	else {
		my (undef, $name) = $class->pop_name($uri);
		$feed->title($name);
	}
	my $link = XML::Atom::Link->new();
	$link->rel('self');
	$link->type('application/atom+xml;type=feed');
	$link->href($uri);
	$feed->add_link($link);
	$feed->updated($row->{Updated});
	$feed->{syncronized} = $row->{Syncronized} || 0; # UNIX timestamp to compare with directory mtime
	$feed->{updated_ts} = $row->{UpdatedTS};
	return $feed;
}

sub list_feed_entries {
	my $self = shift;
	my ($uri) = @_;
	my $sth = $self->sh->prepare("
SELECT DISTINCT e.Uri, e.Title, e.Updated FROM Entry e
JOIN MediaEntry me ON e.Id = me.EntryId
JOIN Media m ON me.MediaId = m.Id
JOIN Feed f ON m.FeedId = f.Id
WHERE f.Uri = ?
ORDER BY e.Uri
	");
	my $list = [];
	$sth->execute($uri);
	while (my $row = $sth->fetchrow_hashref) {
		my $entry = $self->load_entry(URI->new($row->{Uri}));
		push @$list, $entry if $entry;
	}
	return $list;
}

sub list_feed_feeds {
	my $self = shift;
	my ($uri) = @_;
	my $sth = $self->sh->prepare("
SELECT f.Uri, f.Title, f.Updated FROM Feed f
JOIN Feed pf ON f.FeedId = pf.Id
WHERE pf.Uri = ?
ORDER BY f.Uri
	");
	my $list = [];
	$sth->execute($uri);
	while (my $row = $sth->fetchrow_hashref) {
		my $entry = XML::Atom::Entry->new();
		$entry->id($row->{Id});
		if (my $title = $row->{Title}) {
			$entry->title($title);
		}
		else {
			my (undef, $name) = $self->pop_name(URI->new($row->{Uri}));
			$entry->title($name);
		}
		my $link = XML::Atom::Link->new();
		$link->rel('self');
		$link->type('application/atom+xml;type=feed');
		$link->href($row->{Uri});
		$entry->add_link($link);
		$entry->updated($row->{Updated});
		
		my $category = XML::Atom::Category->new();
		$category->term('directory');
		$category->scheme('http://dp-net.com/2009/Atom/EntryType');
		$entry->category($category);

		push @$list, $entry;
	}
	return $list;
}

sub update_feed {
	my $self = shift;
	my ($uri, $title, $updated) = @_;
	my $sth = $self->{sth}->{update_feed} ||= $self->sh->prepare("
UPDATE Feed SET Title = ?, Updated = ? WHERE Uri = ?
	");
	$sth->execute($title, $updated, $uri);
}

sub load_entry {
	my $class = shift;
	my ($uri) = @_;
	$cache->{select_entry_by_uri} ||= $class->sh->prepare("
SELECT Id, Title, Updated FROM Entry
WHERE Uri = ?
	");
	$cache->{select_entry_by_uri}->execute($uri);
	my $row = $cache->{select_entry_by_uri}->fetchrow_hashref or return undef;
	my $entry = XML::Atom::Entry->new();
	$entry->id($row->{Id});
	if (my $title = $row->{Title}) {
		$entry->title($title);
	}
	else {
		my (undef, $name) = $class->pop_name($uri);
		$entry->title($name);
	}
	my $link = XML::Atom::Link->new();
	$link->rel('self');
	$link->type('application/atom+xml;type=entry');
	$link->href($uri);
	$entry->add_link($link);
	$entry->updated($row->{Updated});

	$cache->{select_media_for_entry_by_uri} ||= $class->sh->prepare("
SELECT m.Title, m.Uri, m.Type, i.Description, i.Width, i.Height FROM Media m
JOIN MediaEntry me ON m.Id = me.MediaId
JOIN Entry e ON me.EntryId = e.Id
LEFT OUTER JOIN Image i ON m.Id = i.MediaId
WHERE e.Uri = ?
	");
	$cache->{select_media_for_entry_by_uri}->execute($uri);
	
	while ($row = $cache->{select_media_for_entry_by_uri}->fetchrow_hashref) {
		my $link = XML::Atom::Link->new();
		$link->title($row->{Title}) if $row->{Title};
		$link->rel('alternate');
		$link->type($row->{Type});
		$link->href($row->{Uri});
		$entry->add_link($link);
		if (my $description = $row->{Description}) {
			my $dc_ns = XML::Atom::Namespace->new(dc => 'http://purl.org/dc/elements/1.1/');	
		   	$entry->set($dc_ns, 'description', $description);
		}
		if (my $width = $row->{Width} and my $height = $row->{Height}) {
			$link->elem->setAttribute('width', $width);
			$link->elem->setAttribute('height', $height);
		}
	}	

	return $entry;
}

sub update_entry {
	my $self = shift;
	my ($uri, $title, $updated) = @_;
	my $sth = $self->{sth}->{update_entry} ||= $self->sh->prepare("
UPDATE Entry SET Title = ?, Updated = ? WHERE Uri = ?
	");
	$sth->execute($title, $updated, $uri);
}

sub sibling_links {
	my $self = shift;
	my ($uri) = @_;
	my ($parent_uri, undef) = $self->pop_name($uri);
	my ($previous_link, $next_link);
	my $sth = $self->sh->prepare("
SELECT DISTINCT e.Uri, e.Title FROM Entry e
JOIN MediaEntry me ON e.Id = me.EntryId
JOIN Media m ON me.MediaId = m.Id
JOIN Feed f ON m.FeedId = f.Id
WHERE f.Uri = ?
	AND e.Uri NOT LIKE '%/index' -- HACK: remove index from prev/next links
ORDER BY e.Uri
	");
	$sth->execute($parent_uri);
	my $previous_href, my $previous_title;
	while (my $row = $sth->fetchrow_hashref) {
		if ($previous_href and $previous_href eq $uri) {
			$next_link = XML::Atom::Link->new();
			$next_link->rel('next');
			$next_link->type('application/atom+xml;type=entry');
			$next_link->href($row->{Uri});
			$next_link->title($row->{Title});
			last;
		}
		if ($previous_href and $row->{Uri} eq $uri) {
			$previous_link = XML::Atom::Link->new();
			$previous_link->rel('previous');
			$previous_link->type('application/atom+xml;type=entry');
			$previous_link->href($previous_href);
			$previous_link->title($previous_title);
		}
		$previous_href = $row->{Uri};
		$previous_title = $row->{Title};
	}
	return ($previous_link, $next_link);
}

sub load_media {
	my $self = shift;
	my ($uri) = @_;
	$cache->{select_media_by_uri} ||= $self->sh->prepare("
SELECT Title, Uri, strftime('%s', Updated) AS Updated, Type FROM Media
WHERE Uri = ?
	");
	$cache->{select_media_by_uri}->execute($uri);
	my $row = $cache->{select_media_by_uri}->fetchrow_hashref or return undef;
	return {
		title => $row->{Title},
		uri => $row->{Uri},
		updated => $row->{Updated},
		type => $row->{Type}
	};
}

sub update_image {
	my $class = shift;
	my ($uri, $width, $height, $description) = @_;
	my $sth = $class->sh->prepare("
INSERT OR REPLACE INTO Image (MediaId, Width, Height, Description) VALUES ((SELECT Id FROM Media WHERE Uri = ?), ?, ?, ?)
	");
	$sth->execute($uri, $width, $height, $description);
}

sub load_image {
	my $class = shift;
	my ($uri) = @_;
	my $sth = $class->sh->prepare("
SELECT Width, Height FROM Image i
JOIN Media m ON i.MediaId = m.Id
WHERE m.Uri = ?
	");
	$sth->execute($uri);
	my $row = $sth->fetchrow_hashref or return undef;
	return ($row->{Width}, $row->{Height});
}

sub parent_link {
	my $self = shift;
	my ($uri) = @_;
	my ($parent_uri, $name) = $self->pop_name($uri);
	return undef unless $parent_uri;
	my $feed = $self->load_feed($parent_uri) or return undef;
	my $inline = XML::Atom::Ext::Inline->new();
	if (my $parent_link = $self->parent_link($parent_uri)) {
		$feed->add_link($parent_link);
	}
	$inline->atom($feed);
	my $link = XML::Atom::Link->new();
	$link->href($parent_uri);
	$link->rel('up');
	$link->type('text/html');
	$link->inline($inline);
	return $link;
}

sub pop_name {
	my $class = shift;
	my ($uri) = @_;
	my $parent_uri = URI->new($uri);
	return undef if $uri->path eq '/';
	my @segments = File::Spec->no_upwards($uri->path_segments);
	my $name = pop @segments;
	$name = pop @segments unless length $name; # in case we already have slash at the end
	$parent_uri->path_segments(@segments, '');
	return ($parent_uri, $name);
}

sub append_entry {
	my $class = shift;
	my ($parent_uri, $name) = @_;
	my $uri = URI->new($parent_uri);
	my @segments = File::Spec->no_upwards($parent_uri->path_segments);
	pop @segments if $segments[$#segments] eq '';
	$uri->path_segments(@segments, $name);
	return $uri;
}

sub append_feed {
	my $class = shift;
	my $uri = $class->append_entry(@_);
	$uri->path_segments($uri->path_segments, '');
}

package Attic::Db::UpdateTransaction;

use Time::HiRes qw(gettimeofday tv_interval);

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
	die 'missing DBH' unless $self->{dbh};
	die 'missing URI' unless $self->{uri};

	$self->{dbh}->do('BEGIN EXCLUSIVE TRANSACTION');
	$self->{start_time} = [gettimeofday];
	$self->{in_transaction} = 1;

	{
		my $sth = $self->{dbh}->prepare("
SELECT Id FROM Feed
WHERE Uri = ?
		");
		$sth->execute($self->{uri});
		my $row = $sth->fetchrow_arrayref or do {
			$log->warn("can't create update transaction: feed $self->{uri} not found");
			return undef;
		};
		$self->{feed_id} = $row->[0];
	}

	$self->{dbh}->do('
CREATE TEMPORARY TABLE LocalFeed (Id INTEGER NOT NULL)
	');
	$self->{sth}->{insert_local_feed} = $self->{dbh}->prepare('
INSERT INTO LocalFeed (Id) VALUES (?)
	');
	$self->{sth}->{select_feed} = $self->{dbh}->prepare("
SELECT Id FROM Feed
WHERE Uri = ?
	");
	
	$self->{sth}->{update_feed_timestamp} = $self->{dbh}->prepare("
UPDATE Feed SET Updated = DATETIME(?, 'unixepoch') WHERE Id = ?
	");

	$self->{sth}->{update_feed_syncronized_timestamp} = $self->{dbh}->prepare("
UPDATE Feed SET Syncronized = DATETIME(?, 'unixepoch') WHERE Id = ?
	");

	$self->{dbh}->do('
CREATE TEMPORARY TABLE LocalMedia (Id INTEGER NOT NULL)
	');
	$self->{sth}->{insert_local_media} = $self->{dbh}->prepare('
INSERT INTO LocalMedia (Id) VALUES (?)
	');
	$self->{sth}->{select_media} = $self->{dbh}->prepare("
SELECT Id FROM Media
WHERE Uri = ?
	");

	$self->{dbh}->do('
CREATE TEMPORARY TABLE LocalEntry (Id INTEGER NOT NULL)
	');
	$self->{sth}->{insert_local_entry} = $self->{dbh}->prepare('
INSERT INTO LocalEntry (Id) VALUES (?)
	');
	$self->{sth}->{select_entry} = $self->{dbh}->prepare("
SELECT Id FROM Entry
WHERE Uri = ?
	");
	
	$self->{sth}->{select_mediaentry} = $self->{dbh}->prepare("
SELECT Id FROM MediaEntry
WHERE MediaId = ?
	AND EntryId = ?
	");
	
	return $self;
}

sub process_feed {
	my $self = shift;
	my ($uri, $updated_time) = @_;
	my ($parent_uri, $name) = Attic::Db->pop_name($uri);
	die 'completely broken URI: $uri' unless $self->{uri} eq $parent_uri;
	$self->{sth}->{select_feed}->execute($uri);
	if (my $row = $self->{sth}->{select_feed}->fetchrow_hashref) {
		$self->{sth}->{update_feed_timestamp}->execute($updated_time, $row->{Id});
		$self->{sth}->{insert_local_feed}->execute($row->{Id});
	}
	else {
		$self->{dbh}->do("
INSERT INTO Feed (FeedId, Updated, Uri) VALUES (?, DATETIME(?, 'unixepoch'), ?)
		", {}, $self->{feed_id}, $updated_time, $uri);
		my $sth = $self->{dbh}->prepare("SELECT last_insert_rowid()");
		$sth->execute();
		my $feed_id = $sth->fetchrow_arrayref->[0];
		$self->{sth}->{insert_local_feed}->execute($feed_id);
	}
}

sub process_media {
	my $self = shift;
	my ($uri, $updated_time, $content_type) = @_;
	my ($parent_uri, $name) = Attic::Db->pop_name($uri);
	die 'not blazingly fast URI: $uri' unless $self->{uri} eq $parent_uri;
	$self->{sth}->{select_media}->execute($uri);
	my $media_id;
	if (my $row = $self->{sth}->{select_media}->fetchrow_hashref) {
		$media_id = $row->{Id};
		$self->{dbh}->do("
UPDATE Media SET Updated = DATETIME(?, 'unixepoch'), Type = ? WHERE Id = ?
		", {}, $updated_time, $content_type, $media_id);
	}
	else {
		$self->{dbh}->do("
INSERT INTO Media (FeedId, Updated, Uri, Type) VALUES (?, DATETIME(?, 'unixepoch'), ?, ?)
		", {}, $self->{feed_id}, $updated_time, $uri, $content_type);
		my $sth = $self->{dbh}->prepare("SELECT last_insert_rowid()");
		$sth->execute();
		$media_id = $sth->fetchrow_arrayref->[0];
	}
	$self->{sth}->{insert_local_media}->execute($media_id);
	my @t = split /\./, $name;
	pop @t;
	while (@t) {
		my $e = join '.', @t;
		my $e_uri = URI->new($self->{uri});
		my @segments = $e_uri->path_segments;
		pop @segments if $segments[$#segments] eq '';
		$e_uri->path_segments(@segments, $e);
		my $entry_id;
		$self->{sth}->{select_entry}->execute($e_uri);
		if (my $row = $self->{sth}->{select_entry}->fetchrow_hashref) {
			$entry_id = $row->{Id};
		}
		else {
			$self->{dbh}->do("
INSERT INTO Entry (Title, Updated, Uri) VALUES (?, DATETIME(?, 'unixepoch'), ?)
			", {}, $e, $updated_time, $e_uri);
			my $sth = $self->{dbh}->prepare("SELECT last_insert_rowid()");
			$sth->execute();
			$entry_id = $sth->fetchrow_arrayref->[0];
		}
		$self->{sth}->{insert_local_entry}->execute($entry_id);
		$self->{sth}->{select_mediaentry}->execute($media_id, $entry_id);
		unless (my $row = $self->{sth}->{select_mediaentry}->fetchrow_hashref) {
			$self->{dbh}->do("
INSERT INTO MediaEntry (MediaId, EntryId) VALUES (?, ?)
			", {}, $media_id, $entry_id);
		}
		pop @t;
	}
}

sub commit {
	my $self = shift;
	my ($updated_time, $syncronized_time) = @_;
	
	$self->{sth}->{update_feed_syncronized_timestamp}->execute($syncronized_time, $self->{feed_id});
	$self->{sth}->{update_feed_timestamp}->execute($updated_time, $self->{feed_id});

	$self->{dbh}->do("
DELETE FROM Entry 
WHERE Id IN (
	SELECT EntryId FROM MediaEntry me
	JOIN Media m ON me.MediaId = m.Id
	JOIN Feed f ON m.FeedId = f.Id
	WHERE f.Uri = ?
)
	AND Id NOT IN (
		SELECT Id FROM LocalEntry
	)
	", {}, $self->{uri});

	$self->{dbh}->do("
DELETE FROM Media 
WHERE FeedId = ?
	AND Id NOT IN (
		SELECT Id FROM LocalMedia
	)
	", {}, $self->{feed_id});

	$self->{dbh}->do("
DELETE FROM Feed 
WHERE FeedId = ?
	AND Id NOT IN (
		SELECT Id FROM LocalFeed
	)
	", {}, $self->{feed_id});
	
	$self->{dbh}->do("DROP TABLE LocalEntry");
	$self->{dbh}->do("DROP TABLE LocalFeed");
	$self->{dbh}->do("DROP TABLE LocalMedia");

	$self->{dbh}->do('COMMIT TRANSACTION');
	$self->{in_transaction} = 0;
	my $elapsed_time = tv_interval($self->{start_time});
	$log->info("$self->{uri} reindex complete in $elapsed_time seconds");
}

sub DESTROY {
	my $self = shift;
	if ($self->{in_transaction}) {
		$self->{dbh}->do('ROLLBACK TRANSACTION');
	}
}

1;
