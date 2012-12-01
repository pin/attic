package Attic::Hub::Image;

use strict;
use warnings;

use base 'Attic::Hub::None';

use File::Spec;
use Data::Dumper;
use XML::LibXML;
use Attic::Template;

sub modification_time {
	shift->{image}->{status}->[9];
}

sub populate_entry {
	my $self = shift;
	my ($entry, $request) = @_;
	$entry->title($self->{hub}->name);

	my $category = XML::Atom::Category->new();
	$category->term('image');
	$category->scheme('http://dp-net.com/2009/Atom/EntryType');
	$entry->category($category);

    my $link = XML::Atom::Link->new();
    $link->type('image/jpg');
    $link->rel('alternate');
    $link->href($self->{image}->uri);
    $entry->add_link($link);
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	my $entry = XML::Atom::Entry->new();

	my ($day, $mon, $year) = (localtime $self->{image}->modification_time)[3..5];
	$entry->updated(sprintf "%04d-%02d-%02d", 1900 + $year, 1 + $mon, $day);

    my $link = XML::Atom::Link->new();
    $link->type('text/html');
    $link->title($self->{hub}->{dir}->name);
    $link->rel('up');
    $link->href($self->{hub}->{dir}->uri);
    $entry->add_link($link);

	$self->populate_entry($entry, $request);

	if ($request->param('type') and $request->param('type') eq 'atom') {
		return [200, ['Content-type', 'text/xml'], [$entry->as_xml]];
	}
	else {
		return [200, ['Content-type', 'text/html'], [Attic::Template->transform('image', $entry->elem->ownerDocument)]];
	}
}

1;
