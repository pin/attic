package Attic::Page;

use warnings;
use strict;

use Module::Pluggable search_path => 'Attic::Page', sub_name => 'modules', require => 1, except => 'Attic::Page::Base';
use XML::Atom::Entry;
use Attic::Template;
use Data::Dumper;

my $log = Log::Log4perl->get_logger();

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
	die 'missing router' unless $self->{router};
	my $modules = $self->{modules} = [];
	foreach my $module (sort {$a->priority > $b->priority} $self->modules()) {
		push @$modules, $module->new(router => $self->{router});
	}
	return $self;
}

sub install {
	my $self = shift;
	my $modules = $self->{modules};
	foreach my $module (@$modules) {
		$module->install();
	}
}

sub module {
	my $self = shift;
	my ($entry) = @_;
	foreach my $module (@{$self->{modules}}) {
		return $module if $module->accept($entry);
	}
	return undef;
}

sub populate {
	my $self = shift;
	my ($entry) = @_;
	if (my $module = $self->module($entry)) {
		return $module->populate($entry);
	}
}

sub process {
	my $self = shift;
	my ($request, $entry) = @_;
	if (my $module = $self->module($entry)) {
		return $module->process($request, $entry);
	}
	else {
		return [404, ['Content-type', 'text/plain'], ['no page module']];
	}
}

package Attic::Page::Base;

sub new {
	my $class = shift;
	bless {@_}, $class
}

sub init_db {
	my $class = shift;
}

sub accept {
	my $class = shift;
	my ($entry) = @_;
	return 0;
}

sub priority { 10 }

sub process {
	die 'not implemented';
}

1;
