package Attic::Page::Proxy;

use warnings;
use strict;

use URI;
use Attic::Page;
use Data::Dumper;
#use Plack::App::Proxy;

use base 'Attic::Page::Base';

my $log = Log::Log4perl->get_logger();
#my $proxy = Plack::App::Proxy->new->to_app;

#sub accept {
#	my $self = shift;
#	my ($entry) = @_;
#	return grep {$_->href =~ /\.proxy$/ and $_->rel eq 'alternate'} $entry->link;
#}

#sub populate {
#	my $self = shift;
#	my ($entry) = @_;
#	my $category = XML::Atom::Category->new();
#	$category->term('page');
#	$category->scheme('http://dp-net.com/2009/Atom/EntryType');
#	$entry->category($category);
#}

sub process {
	my $self = shift;
	my ($request, $entry) = @_;
	
#	my $proxy_file_link = grep {$_->href =~ /\.proxy$/ and $_->rel eq 'alternate'} $entry->link;
#	
#	my $path = $self->{router}->path(URI->new($proxy_file_link->href));
#	open my $fh, $path or die "can't read $path: $!";
#	my $uri = <$fh>;
#	chomp $uri;
#	close $fh;
#	my $env = $request->env;
#	$env->{'plack.proxy.url'} = $uri;
#	return $proxy->($env);
}

1;
