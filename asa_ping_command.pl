#!/usr/bin/perl
# Author: Akos Daniel daniel.akos77ATgmail.com
# Filename: <filename>.pl
# Current Version: 0.1 Beta
# Created: 2nd of Feb 2014
# Last Changed: 2nd of Feb 2014
# -----------------------------------------------------------------------------------------------
# Description:
# -----------------------------------------------------------------------------------------------
# This script will capture the output of the issued ping command of a
# Cisco ASA device through an SSH session and save it to a file.
# you can ping a simple host or all network hosts, just use the right netmask in bits.
# This script saves the output of the show arp command. This script is a kind of network scan.
# Usage: asa_ping_command.pl <device IP> <user> <pass> <enable_pass> <login_timeout_in_seconds> <capture_timeout_in_seconds> <network with mask>
# Example: asa_ping_command.pl 4.2.2.2 admin mysecret mypassword 3 3 "192.168.4.0/24";
# -----------------------------------------------------------------------------------------------
# Known issues:
# 
# -----------------------------------------------------------------------------------------------
# Solved Issues:
#
# -----------------------------------------------------------------------------------------------
# Change History:
# 0.1 beta: (2nd of Feb 2014)
# 
# -----------------------------------------------------------------------------------------------
#
# Error Codes for the login:
#   0   = Success
#   255 = Usage error
#   254 = Invalid timeout value
#   252 = Login error
#   249 = Exec prompt not found error
#   244 = Error retrieving configuration
#   245 = Insufficient privileges
#   253 = Unexpected output
#
 
use strict;
use warnings;
use Net::SSH::Expect;
use Net::Netmask; # http://perltips.wikidot.com/module-net:netmask
 
$ENV{'PATH'} = "/usr/bin:". $ENV{'PATH'};
my $command = 'ping';

# The variable $#ARGV is the subscript of the last element of the @ARGV array,
# and because the array is zero-based, the number of arguments given on the command line is $#ARGV + 1.
if( $#ARGV != 6 ) {
	print "Usage: asa_ping_command.pl <device IP> <user> <pass> <enable_pass>
			<login_timeout_in_seconds> <capture_timeout_in_seconds> <\"network with mask\">\n";
	print "Example: asa_ping_command.pl 4.2.2.2 admin mysecret mypassword 3 3 \"192.168.4.0/24\"\n";
	print STDERR "Usage:  asa_ping_command.pl <deviceIP> <user> <pass>
			<enable_pass> <login_timeout_in_seconds> <capture_timeout_in_seconds> <network with mask>\n";
	exit 255;
}
elsif( $ARGV[4] < 1 || $ARGV[4] > 600 ) {
	print "$ARGV[4] is the login timeout and must be an int between 1 and 600  seconds\n";
	print STDERR "$ARGV[4] is the login timeout and must be an int between 1 and  600 seconds\n";
	exit 254;
}
elsif ( $ARGV[5] < 1 || $ARGV[5] > 600 ) {
	print "$ARGV[5] is the capture timeout and must be an int between 1 and 600  seconds\n";
	print STDERR "$ARGV[5] is the capture timeout and must be an int between 1  and 600 seconds\n";
	exit 254;
}
else {

	my $errorCode = 1;
	my @data;
	my $errorString = "\nHost $ARGV[0]:  \n";

	($errorCode, @data) = GetConfig( $ARGV[0], $ARGV[1], $ARGV[2], $ARGV[3],$ARGV[4], $ARGV[5], $ARGV[6] );
 
	# Success.  The command output is in the data variable.
	if( $errorCode == 0 ) {
		
		# write output to file
		
		# create output file name
		$command =~ s/\s/_/g; # take the spaces out
		$command =~ s/\|/_/g; # take the pipes out
		
		my $outfilename = $command."_".$ARGV[0].".txt"; # example: sh_conn_all_MyFirewall.txt
		open STDOUT, '>', "$outfilename";
		foreach ( @data ) { print "$_\n" }; # print the configuration to file
		close (STDOUT);

        exit 0;
	}
	else {
		print STDERR $errorString;

		if( $errorCode == 245 ) {
			print STDERR join " ", @data, "\nEnsure that the device user has sufficient privileges to disable paging and view the config\n";
		}
		else {
			print STDERR join " ", @data, "\n";
		}
		exit $errorCode;
	}
}
 
exit 0;
 
sub GetConfig {
	my $deviceIP=shift; 		# $ARGV[0]
	my $user=shift;				# $ARGV[1]
	my $pass=shift;				# $ARGV[2]
	my $epass=shift;			# $ARGV[3]
	my $login_timeout=shift;	# $ARGV[4]
	my $capture_timeout=shift;	# $ARGV[5]
	my $pingednet=shift;		# $ARGV[6]
	my @config;
	my $msg;
	my $en_command="enable";
	my $term_command="terminal pager line 0";

	# Making an ssh connection with user-password authentication
	
    # 1) construct the object
	my $ssh = Net::SSH::Expect->new (	host => $deviceIP,
										user => $user,
										password=> $pass,
										raw_pty => 1,
										no_terminal => 0,
                                        timeout => $login_timeout
									);
 
	my $login_output = $ssh->login();
    
	if( $@ ) {
		$msg = "Login has failed. Output: $login_output";
		return( 252, $msg );
	}
 
	# login output should contain the right prompt characters
	if( $login_output !~ /\>\s*\z/ ) {
		$msg = "Login has failed. Didn't see device prompt as expected.";
		$ssh->close();
		return( 252, $msg );
	}
 
	# Replace '#' is the prompt character here 
	if( $login_output !~ /\>\s*\z/ ) { 
		# we don't have the '#' prompt, means we still can't exec commands
		$msg = "Exec prompt not found.";
		$ssh->close();
		return( 249, $msg );
	}

	# issue "enable" command
	my $elogin = $ssh->exec($en_command);

	# issue the enable password
	my $elogin2 = $ssh->exec($epass);

	if( $elogin2 !~ /\#\s*\z/ ) { # Replace '#' is the prompt character here
		$msg = "Exec prompt not found.";
		$ssh->close();
		return( 249, $msg );
	}

	# disable paging. The user must have the right for the command!
	my $paging = $ssh->exec( $term_command );
	if ( $paging =~  /\s?%\s/ ) {
		$msg = "Unable to set terminal size to 0 - Insufficient privileges";
		$ssh->close();
		return( 245, $msg);
	}
	
	# issue the ping from the arguments
	# When running a command that causes a huge output use send() instead of exec()
	my $ipblock = Net::Netmask->new($pingednet);
	my $firstip = $ipblock->base();
	my $lastip = $ipblock->broadcast();
	for my $ip ($ipblock->enumerate()) {
		$ssh->send( $command.' '.$ip.' timeout 0' ); 
		$ssh->timeout( $capture_timeout );
		$ssh->peek(1);
		# get output content
		while( my $line = $ssh->read_line() ) {
			if( $line !~ /sh run|Building configuration|Current configuration|in use|most used|^\s*$/ ) { # filter out the dust here.
				push @config, $line;
			}
		}
	}
	# check the arp table
	$ssh->send( 'show arp' ); 
	$ssh->timeout( $capture_timeout );
	$ssh->peek(1);
	# get output content
	while( my $line = $ssh->read_line() ) {
			if( $line !~ /sh run|Building configuration|Current configuration|in use|most used|^\s*$/ ) { # filter out the dust here.
				push @config, $line;
			}
	}
	
	if( @config <= 0 ) {
		$msg = "No data retrieved, the capture timeout may be too low.";
		$ssh->close();
		return( 244, $msg );
	}
 
	if( scalar grep { $_ =~ /^%/ } @config ) {
		# Ensure the output actually returned the required output and not an error
		# message containing '%'
		return( 245, @config );
		$ssh->close();
	}

	return( 0, @config ); # everything was okay, return the captured data
	$ssh->close();
}