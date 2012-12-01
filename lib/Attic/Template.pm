package Attic::Template;

use strict;
use warnings;

use XML::LibXSLT;
use FindBin;
use Log::Log4perl;
use Data::Dumper;

my $xslt = XML::LibXSLT->new();
my $stylesheet_cache = {};
my $log = Log::Log4perl->get_logger();

sub stylesheet {
	my $class = shift;
	my ($name) = @_;
	my $path = File::Spec->catfile($FindBin::Bin, 'template', $name . '.xsl');
	$log->info("parsing $path");
	my $xsl = XML::LibXML->load_xml(location => File::Spec->catfile($FindBin::Bin, 'template', $name . '.xsl'));
	return $xslt->parse_stylesheet($xsl);
}

sub transform {
	my $class = shift;
	my ($name, $doc) = @_;
	my $stylesheet = exists $stylesheet_cache->{$name} ? $stylesheet_cache->{$name} : $class->stylesheet($name);
	my $html = $stylesheet->transform($doc)->toStringHTML;
	$stylesheet_cache->{$name} = $stylesheet unless $stylesheet_cache->{$name};
	return $html;
}


1;
