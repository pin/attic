package Attic::Hub::Video;

use strict;
use warnings;

use base 'Attic::Hub::None';

use File::Spec;
use Data::Dumper;
use XML::LibXML;
use Attic::Template;

sub modification_time {
	shift->{video}->{status}->[9];
}

sub populate_entry {
	my $self = shift;
	my ($entry, $request) = @_;
	$entry->title($self->{hub}->name);

	my $category = XML::Atom::Category->new();
	$category->term('video');
	$category->scheme('http://dp-net.com/2009/Atom/EntryType');
	$entry->category($category);

	{
	    my $link = XML::Atom::Link->new();
	    $link->rel('alternate');
	    $link->type('video/mp4');
	    $link->href($self->{video}->uri);
	    $entry->add_link($link);
	}

	{
	    my $link = XML::Atom::Link->new();
	    $link->rel('alternate');
	    $link->type('image/jpg');
	    $link->href($self->{video}->uri);
	    $entry->add_link($link);
	}
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	my $entry = XML::Atom::Entry->new();

	$self->populate_entry($entry, $request);
	
	my ($day, $mon, $year) = (localtime $self->{video}->modification_time)[3..5];
	$entry->updated(sprintf "%04d-%02d-%02d", 1900 + $year, 1 + $mon, $day);

	$self->{hub}->{dir}->populate_siblings($entry, $self->{hub}->name);

	$entry->add_link($self->{hub}->parent_link);

	if ($request->param('type') and $request->param('type') eq 'atom') {
		return [200, ['Content-type', 'text/xml'], [$entry->as_xml]];
	}
	else {
		return [200, ['Content-type', 'text/html'], [Attic::Template->transform('video', $entry->elem->ownerDocument)]];
	}
}

1;
