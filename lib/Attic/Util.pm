package Attic::Util;

use strict;
use warnings;

use IO::Select;
use IPC::Open3;

sub system_ex {
	my $class = shift;
	my ($command, $log) = @_;
	my $start_time = time;
	if (defined $log) {
		my $command_str = ref $command eq 'ARRAY' ? join ' ', @$command : $command;
		$log->debug("executing $command_str");
	}
	my $pid = open3(*CMD_IN, *CMD_OUT, *CMD_ERR, ref $command eq 'ARRAY' ? @$command : $command);
	close CMD_IN;
	my $selector = IO::Select->new();
	$selector->add(*CMD_ERR, *CMD_OUT);
	my $stderr = '', my $stdout = '';
	while (my @ready = $selector->can_read) {
		foreach my $fh (@ready) {
			if (eof $fh) {
				$selector->remove($fh);
				next;
			}
			if (fileno $fh == fileno CMD_ERR) {
				my $s = scalar <CMD_ERR>;
				$stderr .= $s;
				chomp $s;
				$log->debug("ERR> $s") if defined $log;
			}
			else {
				my $s = scalar <CMD_OUT>;
				$stdout .= $s;
				chomp $s;
				$log->debug("OUT> $s") if defined $log;
			}
		}
	}
	waitpid $pid, 0;
	my $retcode = $? >> 8;
	my $elapsed_time = time - $start_time;
	$log->debug("RETCODE: $retcode, seconds elapsed: $elapsed_time") if defined $log;
	close CMD_OUT;
	close CMD_ERR;
	return $retcode, $stdout, $stderr;
}

1;
