package Attic::Hub;

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
	if (my ($html_f) = grep {$_ eq $self->{name} . '.html'} keys %{$self->{files}}) {
		$log->info("hub $self->{name} init as Page: $html_f");
		$self->{impl} = Attic::Hub::Page->new(hub => $self);
	}
	elsif (my ($image_f) = grep {$_->content_type =~ /^image\//} values %{$self->{files}}) {
		$log->info("hub $self->{name} init as Image: $image_f->{name}");
		$self->{impl} = Attic::Hub::Image->new(hub => $self);
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

sub call {
	my $self = shift;
	my ($env) = @_;
#	$log->info("CALL to hub");
	return $self->{impl}->to_app->($env);
}

1;
