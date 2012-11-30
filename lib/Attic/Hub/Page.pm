package Attic::Hub::Page;

use strict;
use warnings;

use base 'Plack::Component';

use File::Spec;
use Plack::Request;
use XML::LibXML;
use Attic::Template;
use URI::QueryParam;

my $log = Log::Log4perl->get_logger();

#sub prepare_app {
#	$log->info("PAGE prepared");
#}

sub modification_time {
	shift->{page}->{status}->[9];
}

sub call {
	my $self = shift;
	my ($env) = @_;
	my $request = Plack::Request->new($env);
	my $entry = XML::Atom::Entry->new();
	my $category = XML::Atom::Category->new();
	$category->term('page');
	$category->scheme('http://dp-net.com/2009/Atom/EntryType');
	$entry->category($category);
	my ($day, $mon, $year) = (localtime $self->{page}->modification_time)[3..5];
	$entry->updated(sprintf "%04d-%02d-%02d", 1900 + $year, 1 + $mon, $day);
	my $html_doc = XML::LibXML->load_html(location => $self->{page}->path);
	if (my $date = $html_doc->findvalue('/html/head/meta[@name="Date" or @name="date" or @name="DATE"]/@content')) {
		$entry->updated($date);
	}
	$entry->title($html_doc->findvalue('/html/body/h1') || $self->{hub}->name);
	$entry->content(XML::Atom::Content->new());
	foreach my $node ($html_doc->find('/html/body')->[0]->childNodes) {
		next if $node->nodeName eq 'h1';
		$entry->content->elem->appendChild($node);
	}
	if ($request->param('type') and $request->param('type') eq 'atom') {
		return [200, ['Content-type', 'text/plain'], ["page: " . $self->{hub}->name . "\n\n" . $entry->as_xml]];
	}
	else {
		return [200, ['Content-type', 'text/html'], [Attic::Template->stylesheet('page')->transform($entry->elem)->toStringHTML]];
	}
}

1;
