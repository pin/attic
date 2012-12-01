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

1;
