package Attic::Page::Markup;

use warnings;
use strict;

use URI;
use Attic::Page;
use Data::Dumper;

use base 'Attic::Page::Base';

my $log = Log::Log4perl->get_logger();

sub accept {
	my $self = shift;
	my ($entry) = @_;
	return grep {$_->type eq 'text/html' and $_->rel eq 'alternate'} $entry->link;
}

sub populate {
	my $self = shift;
	my ($entry) = @_;
	my $category = XML::Atom::Category->new();
	$category->term('page');
	$category->scheme('http://dp-net.com/2009/Atom/EntryType');
	$entry->category($category);
}

sub process {
	my $self = shift;
	my ($request, $entry) = @_;
	$self->populate($entry);
	my ($html_link) = grep {$_->type eq 'text/html' and $_->rel eq 'alternate'} $entry->link;
	my $path = $self->{router}->path(URI->new($html_link->href));
	my $html_doc = XML::LibXML->load_html(location => $path, recover => 2);
	if (my $date = $html_doc->findvalue('/html/head/meta[@name="Date" or @name="date" or @name="DATE"]/@content')) {
		$entry->updated($date);
	}
	if (my $h1 = $html_doc->findvalue('/html/body/h1')) {
		$entry->title($h1);
	}
	elsif (my $title = $html_doc->findvalue('/html/head/title')) {
		$entry->title($title);
	}
	my $body = XML::LibXML::Element->new('body');
	if (my $html_body_list = $html_doc->find('/html/body')) {
		foreach my $node ($html_body_list->[0]->childNodes) {
			next if $node->nodeName eq 'h1';
			$body->appendChild($node);
		}
	}
	if (my @nodes = $body->childNodes) {
		$entry->content(XML::Atom::Content->new());
		foreach my $node (@nodes) {
			$entry->content->elem->appendChild($node);
		}
	}
	my ($self_link) = grep {$_->rel eq 'self'} $entry->link;
	$self->{router}->{db}->update_entry($self_link->href, $entry->title, $entry->updated);
	my ($parent_uri, $name) = $self->{router}->{db}->pop_name(URI->new($self_link->href));
	if ($name eq 'index') {
		map {$_->href($parent_uri)} grep {$_->rel eq 'self'} $entry->link;
	}
	if ($request->param('type') and $request->param('type') eq 'atom') {
		return [200, ['Content-type', 'text/xml'], [$entry->as_xml]];
	}
	else {
		return [200, ['Content-type', 'text/html'], [Attic::Template->transform('page', $entry->elem->ownerDocument)]];
	}
}

1;
