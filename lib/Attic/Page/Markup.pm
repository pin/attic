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

sub html_doc {
	my $self = shift;
	my ($entry) = @_;
	my ($html_link) = grep {$_->type eq 'text/html' and $_->rel eq 'alternate'} $entry->link;
	my $path = $self->{router}->path(URI->new($html_link->href));
	return XML::LibXML->load_html(location => $path, recover => 2);
}

sub process {
	my $self = shift;
	my ($request, $entry) = @_;
	$self->populate($entry);
	my $html_doc = $self->html_doc($entry);
	if (my $date = $html_doc->findvalue('/html/head/meta[@name="Date" or @name="date" or @name="DATE"]/@content')) {
		$entry->updated($date);
	}
	my ($self_link) = grep {$_->rel eq 'self'} $entry->link;
	my ($parent_uri, $name) = $self->{router}->{db}->pop_name(URI->new($self_link->href));
	my $body = XML::LibXML::Element->new('body');
	if (my $html_body_list = $html_doc->find('/html/body')) {
		foreach my $node ($html_body_list->[0]->childNodes) {
			next if $node->nodeName eq 'h1';
			$body->appendChild($node);
		}
		# replace relative links with absolute in img.src
		foreach my $img_node ($body->findnodes('//img')) {
			my $src = URI->new($img_node->getAttribute('src'));
			$img_node->setAttribute('src', $src->abs($parent_uri));
		}
		# and in a.href
		foreach my $a_node ($body->findnodes('//a')) {
			my $href = URI->new($a_node->getAttribute('href'));
			$a_node->setAttribute('href', $href->abs($parent_uri));
		}
	}
	if (my @nodes = $body->childNodes) {
		$entry->content(XML::Atom::Content->new());
		foreach my $node (@nodes) {
			$entry->content->elem->appendChild($node);
		}
	}
	if (my $h1_list = $html_doc->findnodes('/html/body/h1')) { # choose first H1 as title
		$entry->title($h1_list->[0]->textContent);
	}
	elsif (my $title = $html_doc->findvalue('/html/head/title')) { # or page title
		$entry->title($title);
	}
	else {
		$entry->title($name); # or file basename
	}
	$self->{router}->{db}->update_entry($self_link->href, $entry->title, $entry->updated);
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
