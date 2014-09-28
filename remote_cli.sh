#!/bin/bash
# Author: Akos Daniel daniel.akos77ATgmail.com
# Filename: remote_cli.sh
# Current Version: 0.1 Beta
# Created: 2nd of Feb 2014
# Last Changed: 2nd of Feb 2014
# -----------------------------------------------------------------------------------------------
# Description:
# -----------------------------------------------------------------------------------------------
# This script enables run a command on multiple cisco asa firewall.
# The command ist set with the COMMAND variable.
# The firewall ips are in the file firewall_iplist.
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


#COMMAND="sh run failover"
#COMMAND="sh ntp status"
#COMMAND="sh run | grep 172.16.10.100"
#COMMAND="sh conn all"
#COMMAND="sh version"
#COMMAND="sh inv"
#COMMAND="sh cry key mypubkey rsa | grep Modulus"
COMMAND="ssl server-version tlsv1"
COMMAND_MOD=${COMMAND// /_} # take out the spaces for the output filename
COMMAND_MOD=${COMMAND_MOD//|/_} # and take out the pipes for the output filename. Example result: sh_conn_all

DIR=/home/test/Documents
OUTPUTFILE=asa_top_lists.txt

# When Bash starts, normally, 3 file descriptors are opened
# 0 standard input (stdin)
# 1 standard output (stdout)
# 2 standard error (stderr)
# http://wiki.bash-hackers.org/howto/redirection_tutorial

exec 1>$DIR/$OUTPUTFILE # redirect stdout file descriptor to output file

for HOST in $(cat firewall_iplist | grep -v "^#" | grep -v "^$" | grep asa | grep -v conc) # only PRI Firewalls palo alto and pix is out of scope
#for HOST in $(cat firewall_iplist_all | grep -v "^#" | grep -v "^$" | grep asa) # all Firewalls (PRI,SEC) and palo alto and pix is out of scope
do

	echo $HOST > /dev/tty
	INPUTFILE=$COMMAND_MOD\_$HOST.txt
	echo "--------------------------------------------"
	echo $HOST
	echo "--------------------------------------------"
	echo ""
	./capture_asa_command.pl $HOST myusername mypassword mypassword 2 2 "ssl server-version tlsv1" # I cant give it with a COMMAND variable here :-(
	#./capture_asa_command.pl $HOST myusername mypassword mypassword 4 4 "sh cry key mypubkey rsa | grep Modulus" # I cant give it with a COMMAND variable here :-(
	#./capture_asa_command.pl $HOST myusername mypassword mypassword 1 1 "sh run | grep 172.16.10.100" # I cant give it with a COMMAND variable here :-(
	#./asa_conn_report.pl $INPUTFILE
	#./asa_conn_report_piecharts.pl $INPUTFILE
	echo ""
	echo ""

done
echo "Ready" > /dev/tty