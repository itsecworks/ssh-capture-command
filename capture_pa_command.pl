#!/usr/bin/perl
# Author: Akos Daniel daniel.akos77ATgmail.com
# Filename: capture_pa_command.pl
# Current Version: 0.1 Beta
# Created: 2nd of Feb 2014
# Last Changed: 2nd of Feb 2014
# -----------------------------------------------------------------------------------------------
# Description:
# -----------------------------------------------------------------------------------------------
# This script will capture the output of the issued command of a
# Palo Alto device through an SSH session and save it to a file.
# Usage: capture_running.pl <device IP> <user> <pass> <enable_pass> <login_timeout_in_seconds> <capture_timeout_in_seconds> <your_command_here>
# Example: capture_running.pl 4.2.2.2 admin mysecret mypassword 3 3 "show interface"
#
#
# -----------------------------------------------------------------------------------------------
# Known issues:
# It is not working. the palo alto works not as a cisco asa in ssh.
# -----------------------------------------------------------------------------------------------
# Solved Issues:
#
# -----------------------------------------------------------------------------------------------
# Change History:
# 0.1 beta: (2nd of Feb 2014)
# 
# -----------------------------------------------------------------------------------------------
#
# Error Codes for login:
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
 
$ENV{'PATH'} = "/usr/bin:". $ENV{'PATH'};
 
# The variable $#ARGV is the subscript of the last element of the @ARGV array,
# and because the array is zero-based, the number of arguments given on the command line is $#ARGV + 1.
if( $#ARGV != 5 ) {
	print "Usage: capture_running.pl <device IP> <user> <pass> <enable_pass>
			<login_timeout_in_seconds> <capture_timeout_in_seconds> <\"command\">\n";
	print "Example: capture_running.pl 4.2.2.2 admin mysecret mypassword 3 3 \"show interface\"\n";
	print STDERR "Usage:  capture_running.pl <deviceIP> <user> <pass>
			<enable_pass> <login_timeout_in_seconds> <capture_timeout_in_seconds> <command>\n";
	exit 255;
}
elsif( $ARGV[3] < 1 || $ARGV[3] > 600 ) {
	print "$ARGV[3] is the login timeout and must be an int between 1 and 600  seconds\n";
	print STDERR "$ARGV[4] is the login timeout and must be an int between 1 and  600 seconds\n";
	exit 254;
}
elsif ( $ARGV[4] < 1 || $ARGV[4] > 600 ) {
	print "$ARGV[4] is the capture timeout and must be an int between 1 and 600  seconds\n";
	print STDERR "$ARGV[4] is the capture timeout and must be an int between 1  and 600 seconds\n";
	exit 254;
}
else {

	my $errorCode = 1;
	my @data;
	my $errorString = "\nHost $ARGV[0]:  \n";

	($errorCode, @data) = GetConfig( $ARGV[0], $ARGV[1], $ARGV[2], $ARGV[3],$ARGV[4], $ARGV[5] );
 
	# Success.  The command output is in the data variable.
	if( $errorCode == 0 ) {
		
		# write output to file
		
		# create output file name
		my $command = $ARGV[5];
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
	my $login_timeout=shift;	# $ARGV[3]
	my $capture_timeout=shift;	# $ARGV[4]
	my $command=shift;			# $ARGV[5]
	my @config;
	my $msg;
	my $term_command="set cli pager off"; # pager settings for palo alto

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
	if( $login_output !~ /Last login/ ) {
		$msg = "Login has failed. Didn't see device prompt as expected.";
		$ssh->close();
		return( 252, $msg );
	}
 
 	# disable paging. The user must have the right for the command!
	my $paging = $ssh->exec( $term_command );
	if ( $paging =~  /\s?%\s/ ) {
		$msg = "Unable to set terminal size to 0 - Insufficient privileges";
		$ssh->close();
		return( 245, $msg);
	}
	
	# issue the defined command from the arguments
	# When running a command that causes a huge output use send() instead of exec()
	$ssh->send( $command ); 
	$ssh->timeout( $capture_timeout );
	#$ssh->peek(0);

	# get configuration content
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