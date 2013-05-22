package Attic::Page::Movie;

use warnings;
use strict;

use base 'Attic::Page::Base';

my $log = Log::Log4perl->get_logger();

sub accept {
	my $self = shift;
	my ($entry) = @_;
	return grep {$_->type =~ /^video\// and $_->rel eq 'alternate'} $entry->link;
}

sub populate {
	my $self = shift;
	my ($entry) = @_;
	my $category = XML::Atom::Category->new();
	$category->term('video');
	$category->scheme('http://dp-net.com/2009/Atom/EntryType');
	$entry->category($category);
	foreach my $video_link (grep {$_->type =~ /^video\// and $_->rel eq 'alternate'} $entry->link) {
		$video_link->type('video/mp4');
		my $thumbnail_link = XML::Atom::Link->new();
		$thumbnail_link->rel('alternate');
		$thumbnail_link->type('image/jpg');
		$thumbnail_link->href($video_link->href);
		$entry->add_link($thumbnail_link);
	}
}

sub process {
	my $self = shift;
	my ($request, $entry) = @_;
	
	$self->populate($entry);
	
	my @videos = grep {$_->type =~ /^video\// and $_->rel eq 'alternate'} $entry->link;
	my $video_uri = URI->new($videos[0]->href);
	my $video_path = $self->{router}->path($video_uri);
	
	if ($request->param('type') and $request->param('type') eq 'atom') {
		return [200, ['Content-type', 'text/xml'], [$entry->as_xml]];
	}
	else {
		return [200, ['Content-type', 'text/html'], [Attic::Template->transform('video', $entry->elem->ownerDocument)]];
	}
}

1;