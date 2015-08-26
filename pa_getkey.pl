#!/usr/bin/perl  
# Author: Akos Daniel daniel.akos77ATgmail.com
#
# Filename: pa_getkey.pl
# Current Version: 0.1 beta
# Created: 10th of May 2015
# Last Changed: 10th of May 2015
#
# Description:
# -----------------------------------------------------------------------------------------------
# This script logs in the palo alto firewall through https and get the key to login without username and password.
# This script can be used with a list of palo alto firewalls, with -f.
# Step 1.
# For the login you need a key. The scripts opens the following page on the firewall with your credential, example:
# https://10.13.13.1/api/?type=keygen&user=myusername&password=mypassword
# In the output is your key.
#
# Syntax:
# -----------------------------------------------------------------------------------------------
# $ ./pa_getkey.pl <IP or IP List in file> <username> <password>
#
# Mandatory arguments:
# -----------------------------------------------------------------------------------------------
# <IP> 				: The IP of the palo alto firewall.
# <uername>			: username for https login.
# <password>		: password for httsp login.
#
# Example:
# -----------------------------------------------------------------------------------------------
# $ ./pa_getkey.pl 10.13.13.1 admin password123
#
# Known issues:
# -----------------------------------------------------------------------------------------------
# [solved]
#
# Change History
# -----------------------------------------------------------------------------------------------
# 0.1 beta: (10st of May 2015)
#

1;

sub getkey {

use strict;
use warnings;
use URI::Escape;
use LWP::UserAgent;  
use HTTP::Request;
use XML::LibXML;

my $hostname    = $_[0]; # IP of the firewall or list of IPs
my $username    = $_[1]; # example 'admin'
my $password	= $_[2]; # example 'password123'

my $URL			= 'https://'.$hostname.'/api/?type=keygen&user='.$username.'&password='.$password;

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
my $outid = 1;

###
#the return value is the key

my $xpath  = "/response/result/key"; # xpath_expression (query)
my $sum = 0;

# findnodes function from XML::LibXML::Node Package
my $code = $xmlfile->findnodes($xpath); 

return ($code);
}
