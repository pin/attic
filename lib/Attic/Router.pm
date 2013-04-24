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
use DBI;

my $log = Log::Log4perl->get_logger();

sub path {
	my $self = shift;
	my ($uri) = @_;
	my @segments = File::Spec->no_upwards(grep {$_} $uri->path_segments);
	my $path = File::Spec->catdir($self->{documents_dir}, @segments);
}

sub directory {
	my $self = shift;
	my ($uri, $stat) = @_;
	unless ($stat) {
		$stat = [stat $self->path($uri)] or do {
			delete $self->{directories}->{$uri->path} if exists $self->{directories}->{$uri->path};
			return undef;
		};
	}
	unless (S_ISDIR($stat->[2])) {
		return undef;
	}
	if (my $directory = $self->{directories}->{$uri->path}) {
		return $directory if $directory->modification_time == $stat->[9];
	}
	my $directory_uri = URI->new($uri->path);
	my $dir = Attic::Directory->new(uri => $directory_uri, router => $self, status => $stat);
#	$log->debug("create directory instance: " . $dir->path . ' (' . $uri . ')');
	return $self->{directories}->{$uri->path} = $dir;
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	my $uri = $request->uri;
	$self->discover(URI->new($uri->path));
	while ($uri) {
		if (my $dir = $self->directory($uri)) {
			return $dir->app->($env);
		}
		($uri, undef) = Attic::Directory->pop_name($uri);
	}
	return [500, ['Content-type', 'text/plain'], ['shit happens']];
}

my $version = 5;
my $dbh;
sub dbh {
	return $dbh if $dbh;
	my $db_path = File::Spec->catfile(Attic::Config->value('cache_dir'), 'db.' . $version . '.sqlite3');
	my $is_db_exists = -f $db_path;
	$dbh = DBI->connect("dbi:SQLite:dbname=$db_path", undef, undef, {RaiseError => 1});
	$log->info("database at $db_path connected");
	$dbh->do('PRAGMA synchronous=OFF');
	$dbh->do('PRAGMA foreign_keys=ON');
	return $dbh if $is_db_exists;
	$dbh->do('BEGIN TRANSACTION');
	$dbh->do('CREATE TABLE Directory (
		Id INTEGER PRIMARY KEY AUTOINCREMENT,
		Uri TEXT NOT NULL UNIQUE,
		Name TEXT NOT NULL,
		ParentDirectory INTEGER
	)');
	$dbh->do('CREATE INDEX DirectoryUriIdx ON Directory (Uri)');
	$dbh->do('CREATE INDEX DirectoryParentDirectoryIdx ON Directory (ParentDirectory)');
	$dbh->do('INSERT INTO "Directory" VALUES(1,"/","/",NULL)');
	$dbh->do('CREATE TABLE File (
		Id INTEGER PRIMARY KEY AUTOINCREMENT,
		Uri TEXT NOT NULL UNIQUE,
		Name TEXT NOT NULL,
		ParentDirectory INTEGER
	)');
	$dbh->do('CREATE INDEX FileUriIdx ON File (Uri)');
	$dbh->do('CREATE INDEX FileParentDirectoryIdx ON File (ParentDirectory)');
	$dbh->do('COMMIT TRANSACTION');
	$log->info("database at $db_path initialized");
	return $dbh;
}

sub discover {
	my $self = shift;
	my ($uri) = @_;

	my $path = $self->path($uri);
	my @s = stat $path;
	unless (@s and my $is_other_readable = $s[2] & S_IROTH) {
		return;
	};

	$self->dbh->do('BEGIN TRANSACTION');
	eval {
		if (S_ISREG($s[2])) {
			my ($parent_uri, $name) = Attic::Directory->pop_name($uri);
			my $sth = $self->dbh->prepare("SELECT * FROM Directory WHERE Uri = ?");
			$sth->execute($parent_uri);
			die 'parent directory had not been discovered yet' unless my $row = $sth->fetchrow_hashref;
			$self->update_file($uri, $path, \@s);
		}
		elsif (S_ISDIR($s[2]) and $uri =~ /\/$/) {
			$self->update_directory($uri, $path, \@s);
			$self->dbh->do('CREATE TEMPORARY TABLE Entry (Uri TEXT NOT NULL UNIQUE)');
			my $insert_f_sth = $self->dbh->prepare('INSERT INTO Entry (Uri) VALUES (?)');
			opendir my $dh, $path or die "can't open $path: $!";
			while (my $f = readdir $dh) {
				next if $f =~ /^\./;
				my $f_path = File::Spec->catfile($path, $f);
				my @f_s = lstat $f_path or do {
	#				$log->debug("can't stat $f_path: $!");
					next;
				};
				next unless my $is_other_readable = $f_s[2] & S_IROTH;
				my $f_uri = URI->new($uri);
				my @f_segments = $f_uri->path_segments;
				pop @f_segments if $f_segments[$#f_segments] eq '';
				if (S_ISREG($f_s[2])) {
					$f_uri->path_segments(@f_segments, $f);
					$self->update_file($f_uri, $f_path, \@f_s);
					$insert_f_sth->execute($f_uri);
				}
				elsif (S_ISDIR($f_s[2])) {
					$f_uri->path_segments(@f_segments, $f, '');
					$self->update_directory($f_uri, $f_path, \@f_s);
					$insert_f_sth->execute($f_uri);
				}
#				else {
#				}
			}
			my $sth = $self->dbh->prepare('SELECT * FROM Directory WHERE Uri NOT IN (
				SELECT Uri FROM Entry
			) AND ParentDirectory = (
				SELECT Id FROM Directory WHERE Uri = ?
			)');
			$sth->execute($uri);
			while (my $row = $sth->fetchrow_hashref) {
				$self->delete_directory($row->{Uri});
			}
			$self->dbh->do('DELETE FROM File WHERE Uri NOT IN (
				SELECT Uri FROM Entry
			) AND ParentDirectory = (
				SELECT Id FROM Directory WHERE Uri = ?
			)', {}, $uri);
			$self->dbh->do('DROP TABLE Entry');
		}
		else {
			
		}
	};
	if (my $error = $@) {
		$self->dbh->do('ROLLBACK TRANSACTION');
	}
	else {
		$self->dbh->do('COMMIT TRANSACTION');
	}
}

sub update_file {
	my $self = shift;
	my ($uri, $path, $stat) = @_;
	$log->info("updating file $uri");
	my ($parent_uri, $name) = Attic::Directory->pop_name($uri);
	my $sth = $self->dbh->prepare("SELECT * FROM File WHERE Uri = ?");
	$sth->execute($uri);
	if (my $row = $sth->fetchrow_hashref) {
		my $sth = $self->dbh->prepare("UPDATE File SET Name = ?, ParentDirectory = (
			SELECT Id FROM Directory WHERE Uri = ?
		) WHERE Uri = ?");
		$sth->execute($name, $parent_uri, $uri);
	}
	else {
		my $sth = $self->dbh->prepare("INSERT INTO File (Uri, Name, ParentDirectory) VALUES (?, ?, (
			SELECT Id FROM Directory WHERE Uri = ?))");
		$sth->execute($uri, $name, $parent_uri);
	}
}

sub update_directory {
	my $self = shift;
	my ($uri, $path, $stat) = @_;
	$log->info("updating directory $uri");
	my ($parent_uri, $name) = Attic::Directory->pop_name($uri);
	if ($uri ne '/') {
		my $sth = $self->dbh->prepare("SELECT * FROM Directory WHERE Uri = ?");
		$sth->execute($parent_uri);
		unless (my $row = $sth->fetchrow_hashref) {
			my $parent_path = $self->path($parent_uri);
			my @parent_s = stat $parent_path;
			unless (@parent_s and my $is_other_readable = $parent_s[2] & S_IROTH) {
				return;
			};
			$self->update_directory($parent_uri, $parent_path, \@parent_s);
		}
	}
	my $sth = $self->dbh->prepare("SELECT * FROM Directory WHERE Uri = ?");
	$sth->execute($parent_uri);
	if (my $row = $sth->fetchrow_hashref) {
		my $sth = $self->dbh->prepare("SELECT * FROM Directory WHERE Uri = ?");
		$sth->execute($uri);
		if (my $row = $sth->fetchrow_hashref) {
			my $sth = $self->dbh->prepare("UPDATE Directory SET Name = ?, ParentDirectory = (
				SELECT Id FROM Directory WHERE Uri = ?
			) WHERE Uri = ?");
			$sth->execute($name, $parent_uri, $uri);
		}
		else {
			my $sth = $self->dbh->prepare("INSERT INTO Directory (Uri, Name, ParentDirectory) VALUES (?, ?, (
				SELECT Id FROM Directory WHERE Uri = ?))");
			$sth->execute($uri, $name, $parent_uri);
		}
	}
	else {
		$log->info("ignore $uri (no parent)");
	}
}

sub delete_directory {
	my $self = shift;
	my ($uri) = @_;
	$log->info("delete directory $uri");
	{
		my $sth = $self->dbh->prepare("SELECT * FROM Directory WHERE ParentDirectory IN (SELECT Id FROM Directory WHERE Uri = ?)");
		$sth->execute($uri);
		while (my $row = $sth->fetchrow_hashref) {
			$self->delete_directory($row->{Uri});
		}
	}
	$self->dbh->do('DELETE FROM File WHERE ParentDirectory IN (SELECT Id FROM DIrectory WHERE Uri = ?)', {}, $uri);
	$self->dbh->do('DELETE FROM Directory WHERE ParentDirectory IN (SELECT Id FROM Directory WHERE Uri = ?)', {}, $uri);
	$self->dbh->do('DELETE FROM Directory WHERE Uri = ?', {}, $uri);
}

1;
