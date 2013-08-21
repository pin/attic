package Attic::Page::Feed;

use warnings;
use strict;

use URI;
use Attic::Page;
use Data::Dumper;
use XML::Atom::Feed;

use base 'Attic::Page::Base';

my $log = Log::Log4perl->get_logger();

sub accept {
	my $self = shift;
	my ($entry) = @_;
	return grep {$_->href =~ /\.feed$/ and $_->rel eq 'alternate'} $entry->link;
}

sub priority { 5 }

sub populate {
	my $self = shift;
	my ($entry) = @_;
	my $category = XML::Atom::Category->new();
	$category->term('feed');
	$category->scheme('http://dp-net.com/2009/Atom/EntryType');
	$entry->category($category);
}

sub process {
	my $self = shift;
	my ($request, $entry) = @_;
	$self->populate($entry);
	my ($self_link) = grep {$_->rel eq 'self'} $entry->link;
	my ($parent_uri, $name) = $self->{router}->{db}->pop_name(URI->new($self_link->href));
	
#	my $feed_link = grep {$_->href =~ /\.feed$/ and $_->rel eq 'alternate'} $entry->link;
#	my $path = $self->{router}->path(URI->new($feed_link->href));
#	open my $fh, $path or die "can't read $path: $!";
#	close $fh;

	my $feed = $self->{router}->{directory}->recent_entries($request, XML::Atom::Feed->new(), $parent_uri);
	
	if (my $parent_link = $self->{router}->{db}->parent_link(URI->new($self_link->href))) {
		$feed->add_link($parent_link);
	}

	$feed->title($entry->title);

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
		return $self->not_found($request, $parent_uri, $feed->title);
	}
}

1;
