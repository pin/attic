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
    $link->rel('alternate');
    $link->type('image/jpg');
    $link->href($self->{image}->uri);
    $entry->add_link($link);
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	my $entry = XML::Atom::Entry->new();

	$self->populate_entry($entry, $request);
	
	my ($day, $mon, $year) = (localtime $self->{image}->modification_time)[3..5];
	$entry->updated(sprintf "%04d-%02d-%02d", 1900 + $year, 1 + $mon, $day);

	$self->{hub}->{dir}->populate_siblings($entry, $self->{hub}->name);

	if (my $exif = $self->{image}->exif) {
		my $exif_ns = XML::Atom::Namespace->new(exif => 'http://dp-net.com/2012/Exif');
		$entry->set($exif_ns, 'exposure', $exif->{ExposureTime}) if $exif->{ExposureTime};	
		$entry->set($exif_ns, 'aperture', $exif->{ApertureValue}) if $exif->{ApertureValue};	
		$entry->set($exif_ns, 'iso', $exif->{ISO}) if $exif->{ISO};	
		$entry->set($exif_ns, 'f', $exif->{FocalLength}) if $exif->{FocalLength};	
		$entry->set($exif_ns, 'camera', $exif->{Model}) if $exif->{Model};
		$entry->set($exif_ns, 'lens', $exif->{LensType}) if $exif->{LensType};
		$entry->set($exif_ns, 'date', $exif->{DateTimeOriginal}) if $exif->{DateTimeOriginal};
	}
	
	my $dc_ns = XML::Atom::Namespace->new(dc => 'http://purl.org/dc/elements/1.1/');	
	if (my $dc_title = $self->{image}->xmp_param('dc', 'Title')) {
#    	$entry->set($dc_ns, 'title', $dc_title);
    	$entry->title($dc_title);
	}
	if (my $dc_description = $self->{image}->xmp_param('dc', 'Description')) {
    	$entry->set($dc_ns, 'description', $dc_description);
	}

	$entry->add_link($self->{hub}->parent_link);

	if ($request->param('type') and $request->param('type') eq 'atom') {
		return [200, ['Content-type', 'text/xml'], [$entry->as_xml]];
	}
	else {
		return [200, ['Content-type', 'text/html'], [Attic::Template->transform('image', $entry->elem->ownerDocument)]];
	}
}

1;
