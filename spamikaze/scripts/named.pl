#!/usr/bin/perl 

# named.pl
#
# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Copyright (C) 2003 Rik van Riel <riel@surriel.com>
# Copyright (C) 2004 Hans Spaans  <cj.spaans@nexit.nl>
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#        http://spamikaze.nl.linux.org/
#
# generates named zone files from the spamikaze database, run this
# from a cronjob every few minutes so removals from the list are fast
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";

use Spamikaze;

#
# All configuration is done through the config file, /etc/spamikaze/config
# or ~/.spamikaze/config
#
my $dnsbl_location = $Spamikaze::dnsbl_zone_file;
my $dnsbl_url_base = $Spamikaze::dnsbl_url_base;
my $ttl = $Spamikaze::dnsbl_ttl;
my $dnsbl_a        = "{REVIP}\t$ttl\tIN\tA\t 127.0.0.2\n";
my $dnsbl_txt      = "\t\t$ttl\tIN\tTXT\t\"$dnsbl_url_base\{IP\}\"\n";
my $zone_header = '';

#
# construct the header for the dnsbl zone
# 
sub build_zone_header 
{
	my $dnsbl_domain = $Spamikaze::dnsbl_domain;
	my $primary_ns = $Spamikaze::dnsbl_primary_ns;
	my @secondary_nses = split /\s+/, $Spamikaze::dnsbl_secondary_nses;
	my $timestamp = time();
	my $secondary_ns;

	$zone_header .= "; automatically generated by Spamikaze\n";
	$zone_header .= "\$TTL 864000 ; 1 week, 3 days for non-dnsbl data\n";
	$zone_header .= "@\tIN\tSOA\t$primary_ns.\troot.$primary_ns. \(\n";
	$zone_header .= "\t\t\t\t$timestamp\t; serial\n";
	$zone_header .= "\t\t\t\t3600\t\t; refresh \(1 hour\)\n";
	$zone_header .= "\t\t\t\t3600\t\t; retry \(1 hour\)\n";
	$zone_header .= "\t\t\t\t864000\t\t; expire \(1 week, 3 days\)\n";
	$zone_header .= "\t\t\t\t$ttl\t\t; negative\n";
	$zone_header .= "\t\t\t\t\)\n";
	
	$zone_header .= "\tIN\tNS\t$primary_ns.\n";
	foreach $secondary_ns (@secondary_nses) {
		$zone_header .= "\tIN\tNS\t$secondary_ns.\n";
	}

	if (defined $Spamikaze::dnsbl_address) {
		$zone_header .= "\tIN\tA\t$Spamikaze::dnsbl_address\n";
	}

	$zone_header .= "\$ORIGIN\t$dnsbl_domain.\n";
	$zone_header .= "; standard dnsbl test entry\n";
	$zone_header .= "2.0.0.127\tIN\tA\t127.0.0.2\n";
	$zone_header .= "\t\tIN\tTXT\t$dnsbl_domain test entry\n";
	$zone_header .= "; dnsbl data starts here\n";
}

sub main {
	my $ip;

	open( ZONEFILE, ">$dnsbl_location.$$" )
	  or die("Can't open $dnsbl_location.$$ for writing: $!");
	flock( ZONEFILE, 2 );
	seek( ZONEFILE, 0, 2 );

	build_zone_header;
	print ZONEFILE $zone_header;

	foreach $ip ($Spamikaze::db->get_listed_addresses()) {
		my $txt_record = $dnsbl_txt;
		my $a_record   = $dnsbl_a;
		my $revip      = $ip;

		$revip =~ s/(\d+)\.(\d+)\.(\d+)\.(\d+)/$4.$3.$2.$1/;
		$a_record   =~ s/\{REVIP\}/$revip/;
		$txt_record =~ s/\{IP\}/$ip/;

		print ZONEFILE $a_record;
		print ZONEFILE $txt_record;
	}
	print ZONEFILE "; dnsbl file complete \(generated by Spamikaze\)\n";

	close ZONEFILE;

	if ( !rename "$dnsbl_location.$$", "$dnsbl_location" ) {
		warn "rename $dnsbl_location.$$ to $dnsbl_location failed: $!\n";
	}

}

&main;
