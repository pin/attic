package Attic::Hub; # maybe rename to Pile?

use warnings;
use strict;

use base 'Plack::Component';

use Plack::Request;
use Data::Dumper;
use Log::Log4perl;
use File::Spec;

use Attic::Hub::Page;
use Attic::Hub::Image;
use Attic::Hub::None;

my $log = Log::Log4perl->get_logger();

sub prepare_app {
	my $self = shift;
	if (my ($html_name) = grep {$_ eq $self->{name} . '.html'} keys %{$self->{files}}) {
		$log->info("hub $self->{name} init as Page: $html_name");
		$self->{impl} = Attic::Hub::Page->new(hub => $self, page => $self->{files}->{$html_name});
	}
	elsif (my ($image_f) = grep {$_->content_type =~ /^image\//} values %{$self->{files}}) {
		$log->info("hub $self->{name} init as Image: $image_f->{name}");
		$self->{impl} = Attic::Hub::Image->new(hub => $self, image => $image_f);
	}
	else {
		$log->info("hub $self->{name} init as None");
		$self->{impl} = Attic::Hub::None->new(hub => $self);
	}
	$self->{impl}->to_app;
}

sub add_file {
	my $self = shift;
	my ($file) = @_;
	$self->{files}->{$file->{name}} = $file;
}

sub uri {
	my $self = shift;
	return $self->{dir}->{uri} if $self->{name} eq 'index';
	my $uri = URI->new($self->{dir}->{uri});
	my @s = $uri->path_segments;
	pop @s;
	$uri->path_segments(@s, $self->{name});
	return $uri;
}

sub title {
	shift->{impl}->title;
}

sub name {
	shift->{name};
}

sub modification_time {
	shift->{impl}->modification_time;
}

sub call {
	my $self = shift;
	my ($env) = @_;
	return $self->{impl}->to_app->($env);
}

sub populate_entry {
	shift->{impl}->populate_entry(@_);
}

sub parent_link {
	my $self = shift;
	return $self->{dir}->parent_link if $self->{name} eq 'index';
	my $inline = XML::Atom::Ext::Inline->new();
	my $feed = XML::Atom::Feed->new();
	$feed->add_link($self->{dir}->parent_link);
	$feed->title($self->{dir}->name);
	$inline->atom($feed);
	my $link = XML::Atom::Link->new();
	$link->href($self->{dir}->uri);
	$link->rel('up');
	$link->type('text/html');
	$link->inline($inline);
	return $link;
}

1;
