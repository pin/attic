package Attic::ThumbnailSize;

use warnings;
use strict;

use XML::LibXSLT;
use XML::LibXML;
use Data::Dumper;

sub new {
	my $class = shift;
	my $self = bless {request => undef}, $class;
	XML::LibXSLT->register_function('http://dp-net.com/2013/th', 'th_size', sub {
		$self->th_size(@_);
	});
	XML::LibXSLT->register_function('http://dp-net.com/2013/th', 'th_px', sub {
		$self->th_px(@_);
	});
	return $self;
}

sub set_request {
	my $self = shift;
	my ($request) = @_;
	$self->{request} = $request;
}

sub th_size {
	my $self = shift;
	my ($size, $width, $height) = @_;
	die 'illegal state' unless exists $self->{request};
	if ($size eq 'large' and my $clientWidth = $self->{request}->cookies->{'clientWidth'} and my $clientHeight = $self->{request}->cookies->{'clientHeight'}) {
		$clientHeight = $clientHeight - 50 if $clientHeight > 900; # preserve space for header
		$clientWidth = $clientWidth - 40 if $clientWidth > 800; # preserve space for figure left margin
		my $px = $self->calculate_px($clientWidth, $clientHeight, $width, $height);
		return $self->th_px($px, $width, $height);
	}
	elsif ($size eq 'small') {
		return $self->th_px(300, $width, $height);
	}
	else {
		return $self->th_px(800, $width, $height);
	}
}

sub th_px {
	my $class = shift;
	my ($px, $width, $height) = @_;
	my $max_aspect = $width > $height ? $width : $height;
	if ($max_aspect < $px) {
		return XML::LibXML::NodeList->new(
			XML::LibXML::Text->new($max_aspect),
			XML::LibXML::Text->new($width),
			XML::LibXML::Text->new($height)
		);
	}
	else {
		my $ratio = $px / $max_aspect;
		return XML::LibXML::NodeList->new(
			XML::LibXML::Text->new($px),
			XML::LibXML::Text->new(int($width * $ratio)),
			XML::LibXML::Text->new(int($height * $ratio))
		);
	}
}

our @aspects = (300, 350, 450, 600, 800, 1000, 1200);

sub fit_px {
	my $class = shift;
	my ($px) = @_;
	my $standard_px = $aspects[0];
	foreach my $aspect (@aspects) {
		if ($aspect > $px) {
			last;
		}
		else {
			$standard_px = $aspect;
		}
	}
	return $standard_px;
}

sub calculate_px {
	my $class = shift;
	my ($clientWidth, $clientHeight, $imageWidth, $imageHeight) = @_;
	my $px = $aspects[0];
	if ($clientWidth / $clientHeight > $imageWidth / $imageHeight) {
		foreach my $s (@aspects) {
			if ($clientHeight > $s) {
				$px = $s;
			}
			else {
				last;
			}
		}
		if ($imageWidth > $imageHeight) {
			$px = $imageWidth / $imageHeight * $px;
		}
	}
	else {
		foreach my $s (@aspects) {
			if ($clientWidth > $s) {
				$px = $s;
			}
			else {
				last;
			}
		}
		if ($imageWidth < $imageHeight) {
			$px = $imageHeight / $imageWidth * $px;
		}
	}
	return $class->fit_px($px);
}

1;
