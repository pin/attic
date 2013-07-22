package Attic::Page::Markdown;

use warnings;
use strict;

use Text::Markdown::Discount;
use XML::LibXML;
use Log::Log4perl;

use base 'Attic::Page::Markup';

my $log = Log::Log4perl->get_logger();

sub accept {
	my $self = shift;
	my ($entry) = @_;
	return grep {$_->type eq 'text/plain' and $_->rel eq 'alternate'} $entry->link;
}

sub html_doc {
	my $self = shift;
	my ($entry) = @_;
	my ($text_link) = grep {$_->type eq 'text/plain' and $_->rel eq 'alternate'} $entry->link;
	my $path = $self->{router}->path(URI->new($text_link->href));
	my $text = do {
		local $/ = undef;
		open my $fh, "<", $path or die "can't read $path: $!";
		<$fh>;
	};
	my $html = Text::Markdown::Discount::markdown($text);
	return XML::LibXML->load_html(string => $html, recover => 2);
}

1;
