#!/usr/bin/perl  
# Author: Akos Daniel daniel.akos77ATgmail.com
#
# Filename: pa_getit.pl
# Current Version: 0.1 beta
# Created: 10th of May 2015
# Last Changed: 10th of May 2015
#
# Description:
# -----------------------------------------------------------------------------------------------
# This script logs in the palo alto firewall through http and issues a command and gives back the output.
# This script can be used with a list of palo alto firewalls, with -f.
# Step 1.
# For the login you need a key. The scripts opens the following page on the firewall with your credential, example:
# https://10.13.13.1/api/?type=keygen&user=myusername&password=mypassword
# In the output is your key.
# Step 2.
# After that the script just use the key like this example:
# $ ./pa_getit.pl 10.13.13.1 admin password123 "show pbf rule all"
#
# Syntax:
# -----------------------------------------------------------------------------------------------
# $ ./pa_getit.pl <IP or IP List in file> <username> <password> <'command'>
#
# Mandatory arguments:
# -----------------------------------------------------------------------------------------------
# <IP> 				: The IP of the palo alto firewall.
# <uername>			: username for https login.
# <password>		: password for httsp login.
# <"command">		: command to issue in the firewall. just like "<show><pbf><rule><all><%2Fall><%2Frule><%2Fpbf><%2Fshow>"
#
# Example:
# -----------------------------------------------------------------------------------------------
# $ ./pa_getit.pl 10.13.13.1 admin password123 '<show><pbf><rule><all><%2Fall><%2Frule><%2Fpbf><%2Fshow>'
#
# Known issues:
# -----------------------------------------------------------------------------------------------
# [solved]
# -----------------------------------------------------------------------------------------------
# Change History
# -----------------------------------------------------------------------------------------------
# 0.1 beta: (10st of May 2015)

use strict;
use warnings;
use URI::Escape;
use LWP::UserAgent;  
use HTTP::Request;
use XML::LibXML;
require 'pa_getkey.pl';

my @hostname; 				# IP of the firewall or list of IPs
my $username    = $ARGV[1]; # example 'admin'
my $password	= $ARGV[2]; # example 'password123'
my $command		= $ARGV[3]; # command to issue without URL encoding.
							# Example: <show><pbf><rule><all><%2Fall><%2Frule><%2Fpbf><%2Fshow>
							#			<show><dns-proxy><settings><%2Fsettings><%2Fdns-proxy><%2Fshow>

###
# Check if the first Argument is a file or a sinlge IP
#
my $filename = $ARGV[0];
my @hostnames;

if (-f $filename) {	# 1. If file save the IPs in @hostnames Array
	print "This is a file.";
	open (PARSEFILE,$ARGV[0]) || die ("==| Error! Could not open file $ARGV[0]"); # open the file to read

	print "\nLoading the IPs from $ARGV[0]...";

	@hostnames = <PARSEFILE>;
	print "Done\n";

	close (PARSEFILE);
}
else	{	# 2. If not a file and IP save it in @hostnames Array
	$hostnames[0]    = $ARGV[0]; # IP of the firewall;
}

foreach my $hostname (@hostnames) {

	###
	# Lets call pa_getkey.pl with input:
	# - username
	# - password
	# on the @hostname Array.
	# The expected output is the key.
	#
	
	my $httpskey =  getkey($hostname, $username, $password);
	$httpskey =~ s/<key>//g;
	$httpskey =~ s/<\/key>//g;
	
	###
	# Issue the required command
	#
	# command with URL encoding. See http://url-encoder.de/
	# my $urlcommand	= uri_escape($command);
	my $urlcommand		= $command;
	my $URL				= 'https://'.$hostname.'/api/?type=op&key='.$httpskey.'&cmd='.$urlcommand;

	my $xml_string;

	my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
	my $header = HTTP::Request->new(GET => $URL);  
	my $request = HTTP::Request->new('GET', $URL, $header);  
	my $response = $ua->request($request);  

	if ($response->is_success){  
		# input the xml content into var
		$xml_string = $response->content;
	}
	elsif ($response->is_error){  
		print "Error:$URL\n";  
		print $response->error_as_HTML;  
	}

	my $parser = XML::LibXML->new();
	#load_xml function from XML::LibXML::Parser Package
	my $xmlfile = XML::LibXML->load_xml(string => $xml_string);
	
	###
	# Write the outout in a file
	#
	$hostname =~ s/\n//g;
    $hostname =~ s/\r//g;
	my $ofilename	= $hostname . "_output.txt";
	open(my $fh, '>', $ofilename);
	print $fh $xml_string;
	print "Write output to file done\n";
	print "\n";
	close $fh;
}
