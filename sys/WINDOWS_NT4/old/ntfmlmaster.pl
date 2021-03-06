#!/usr/local/bin/perl
#
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");


########################################
# THIS IS THE MASTER DAEMON TO CONTROL
#      fml.pl
#      fmlserv.pl 
#      msend.pl
########################################

$NTFML_CHECK_PERIOD = 10;

# ARGV;
$ML_DIR = shift;

# try chdir (test of existence)
chdir $ML_DIR || die("CANNOT CHSIR $ML_DIR\n");


for (;;) {
    undef @ML;
    &GetMLLists($ML_DIR, *ML);

    for (@ML) {
	next if $_ eq "etc";

	print "Processing the MaliList [$_]\n";

	$host    = "hikari.sapporo.iij.ad.jp";
	$host    = "hikari";
	$pw_file = "$ML_DIR/$_/etc/pop.passwd";
	$dir     = "$ML_DIR/$_";

	$exec = "perl ntfml.pl -host $host -user $_ -pwfile $pw_file $dir";
	system $exec;

	$exec = "perl ntmsend.pl -host $host -user $_ -pwfile $pw_file $dir";
	system $exec;
    }

    sleep $NTFML_CHECK_PERIOD;
}

exit 0;

# 
sub GetMLLists
{
    local($dir, *ML) = @_;

    opendir(DIRD, $dir);
    for (readdir(DIRD)) {
	next if /^\./;
	if (-d "$dir/$_") { push(@ML, $_);} 
    }
    closedir(DIRD);
}

1;
