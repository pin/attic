package Attic::Config;

use warnings;
use strict;

use File::Spec;
use FindBin;
use Config::IniFiles;

my $local_path = File::Spec->catfile($FindBin::Bin, 'etc', 'home.conf');
#$local_path = '/home/pin/src/attic/etc/home.conf';
my $path = '/etc/attic/default.conf';

my $ini_cache;
sub ini {
	my $class = shift;
	return $ini_cache if $ini_cache;
	return $ini_cache = -f $local_path ? Config::IniFiles->new(-file => $local_path) : Config::IniFiles->new(-file => $path);
} 

sub value {
	my $class = shift;
	my ($key) = @_;
	return $class->ini->val('main', $key);
}

1;
