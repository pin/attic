package Attic::Hub::None;

use strict;
use warnings;

use base 'Plack::Component';

use File::Spec;

sub modification_time {
	my $self = shift;
	my $modification_time = 0;
	foreach my $file (values %{$self->{hub}->{files}}) {
		$modification_time = $file->modification_time if $file->modification_time > $modification_time;
	}
	return $modification_time;
}

sub title {
	shift->{hub}->name;
}

sub populate_entry {
	my $self = shift;
	my ($entry, $request) = @_;
	my $category = XML::Atom::Category->new();
	$category->term('none');
	$category->scheme('http://dp-net.com/2009/Atom/EntryType');
	$entry->category($category);
}

sub call {
	my $self = shift;
	my ($env) = @_;
	return [404, ['Content-type', 'text/plain'], ["Nothing!"]];
}

1;
