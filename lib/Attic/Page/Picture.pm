package Attic::Page::Picture;

use warnings;
use strict;

use URI;
use Attic::Page;
use Data::Dumper;
use Image::ExifTool;

use base 'Attic::Page::Base';

my $log = Log::Log4perl->get_logger();
my $et = Image::ExifTool->new();

sub accept {
	my $self = shift;
	my ($entry) = @_;
	return grep {$_->type =~ /^image\// and $_->rel eq 'alternate'} $entry->link;
}

sub populate {
	my $self = shift;
	my ($entry) = @_;
	my $category = XML::Atom::Category->new();
	$category->term('image');
	$category->scheme('http://dp-net.com/2009/Atom/EntryType');
	$entry->category($category);
	foreach my $image_link (grep {$_->type =~ /^image\// and $_->rel eq 'alternate'} $entry->link) {
		$image_link->type('image/jpg');
#		my ($width, $height) = $self->{router}->{db}->load_image($image_link->href);
#		if ($width and $height) {
#			$image_link->elem->setAttribute('width', $width);
#			$image_link->elem->setAttribute('height', $height);
#		}
	}
}

sub process {
	my $self = shift;
	my ($request, $entry) = @_;
	
	$self->populate($entry);
	
	my @images = grep {$_->type =~ /^image\// and $_->rel eq 'alternate'} $entry->link;
	my $image_uri = URI->new($images[0]->href);
	my $image_path = $self->{router}->path($image_uri);
	
	if ($et->ExtractInfo($image_path)) {
		my $exif = $et->GetInfo({Group0 => ['EXIF', 'MakerNotes'], Group1 => ['XMP-dc', 'XMP-dpn']});
		my $exif_ns = XML::Atom::Namespace->new(exif => 'http://dp-net.com/2012/Exif');
		$entry->set($exif_ns, 'exposure', $exif->{ExposureTime}) if $exif->{ExposureTime};	
		$entry->set($exif_ns, 'aperture', $exif->{ApertureValue}) if $exif->{ApertureValue};	
		$entry->set($exif_ns, 'iso', $exif->{ISO}) if $exif->{ISO};	
		$entry->set($exif_ns, 'f', $exif->{FocalLength}) if $exif->{FocalLength};	
		$entry->set($exif_ns, 'camera', $exif->{Model}) if $exif->{Model};
		$entry->set($exif_ns, 'date', $exif->{DateTimeOriginal}) if $exif->{DateTimeOriginal};
		if (my $film = $exif->{Film}) {
			if (my $lens = $et->GetValue('Lens')) {
				$entry->set($exif_ns, 'lens', $lens);
			}
			$entry->set($exif_ns, 'film', $film);
		}
		else {
			$entry->set($exif_ns, 'lens', $exif->{LensModel}) if $exif->{LensModel};
		}
		my $dc_ns = XML::Atom::Namespace->new(dc => 'http://purl.org/dc/elements/1.1/');	
		if (my $dc_title = $exif->{'Title'}) {
	    	$entry->title($dc_title);
		}
		if (my $dc_description = $exif->{'Description'}) {
	    	$entry->set($dc_ns, 'description', $dc_description);
		}
		elsif (my $dpn_location = $exif->{'Location'}) {
			$entry->set($dc_ns, 'description', $dpn_location);
		}
	}
	
	$self->{router}->{db}->update_entry(URI->new($request->uri->path), $entry->title, $entry->updated);

	if ($request->param('type') and $request->param('type') eq 'atom') {
		return [200, ['Content-type', 'text/xml'], [$entry->as_xml]];
	}
	else {
		return [200, ['Content-type', 'text/html'], [Attic::Template->transform('image', $entry->elem->ownerDocument)]];
	}
}

1;
