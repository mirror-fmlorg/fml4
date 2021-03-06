#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#


package MySQL;


sub Log { &main::Log(@_);}


sub DataBases::Execute
{
    my ($e, $mib, $result, $misc) = @_;

    if ($main::debug) {
	while (($k, $v) = each %$mib) { print "MySQL: $k => $v\n";}
    }

    if ($mib->{'_action'}) {
	# initialize
	&Init($mib);
	if ($mib->{'error'}) { 
	    &Log("ERROR: MySQL::Init() fails"); 
	    &Log("ERROR: MySQL: $mib->{'error'}"); 
	    return 0;
	}

	&MySQL::Connect($mib);
	if ($mib->{'error'}) { 
	    &Log("ERROR: MySQL: $mib->{'error'}"); 
	    return 0;
	}

	if ($mib->{'_action'} eq 'get_status') {
	    &Status($mib);
	}
	elsif ($mib->{'_action'} eq 'num_active') {
	    &Count($mib, 'actives');
	}
	elsif ($mib->{'_action'} eq 'num_member') {
	    &Count($mib, 'members');
	}
	elsif ($mib->{'_action'} eq 'get_active_list' ||
	    $mib->{'_action'} eq 'dump_active_list') {
	    &GetActiveList($mib);
	}
	elsif ($mib->{'_action'} eq 'get_member_list' ||
	       $mib->{'_action'} eq 'dump_member_list') {
	    &GetMemberList($mib);
	}
	elsif ($mib->{'_action'} eq 'active_p') {
	    $mib->{'_result'} = &ActiveP($mib, $mib->{'_address'});
	}
	elsif ($mib->{'_action'} eq 'member_p') {
	    $mib->{'_result'} = &MemberP($mib, $mib->{'_address'});
	}
	elsif ($mib->{'_action'} eq 'admin_member_p') {
	    $mib->{'_result'} = &AdminMemberP($mib, $mib->{'_address'});
	}
	elsif ($mib->{'_action'} eq 'add' ||
	       $mib->{'_action'} eq 'bye' ||
	       $mib->{'_action'} eq 'subscribe'   ||
	       $mib->{'_action'} eq 'unsubscribe' ||
	       $mib->{'_action'} eq 'on'     ||
	       $mib->{'_action'} eq 'off'    ||
	       $mib->{'_action'} eq 'digest' ||
	       $mib->{'_action'} eq 'matome' ||
	       $mib->{'_action'} eq 'addadmin' ||
	       $mib->{'_action'} eq 'byeadmin' ) {
	    &__ListCtl($mib);
	}
	elsif ($mib->{'_action'} eq 'store_article') {
	    # &Distribute() calls this function after saving article
	    # at spool/$ID
	    # If you store ML articles to DB, please write the code here.
	    ;
	}
	elsif ($mib->{'_action'} eq 'store_subscribe_mail') {
	    # &AutoRegist() calls this function after subscribe the address
	    # If you store the request mail to DB, please write the code here.
	    ;
	}
	else {
	    &Log("ERROR: MySQL: unkown ACTION $mib->{'_action'}");
	}

	if ($mib->{'error'}) { 
	    &Log("ERROR: MySQL: $mib->{'error'}"); 
	    return 0;
	}

	&Close;
	if ($mib->{'error'}) { 
	    &Log("ERROR: MySQL: $mib->{'error'}"); 
	    return 0;
	}

	# O.K.
	return 1;
    }
    else {
	&Log("ERROR: MySQL: no given action to do");
    }
}


sub Init
{
    my ($mib) = @_;
    my ($driver, $database, $host, $user, $password, $dsn);

    if ($debug) {
	for ('host', 'port', 'user', 'password') {
	    &Log("MySQL: \$mib->{$_} = $mib->{$_}");
	}
    }

    use DBI;
    use DBD::mysql;

    $driver   = 'mysql';
    $database = $mib->{'dbname'};
    $host     =  $mib->{'host'} || 'localhost';
    $user     = $mib->{'user'}     || 'fml' || $NULL;
    $password = $mib->{'password'} || $NULL;
    $dsn      = "DBI:$driver:$database:$host";

    $dbh = DBI->connect($dsn, 'fukachan', 'uja');
    if (! $dbh) { $mib->{'error'} = $DBI::errstr;}
}


# dummy ?
sub Connect { my ($mib) = @_;}

sub Close   
{ 
    my ($mib) = @_;

    $res->finish;
    $dbh->disconnect;
}


### &__Execute($mib, $query)
sub __Execute
{
    my ($mib, $query) = @_;

    $res = $dbh->prepare($query);
    $res->execute;

    if (! $res) {
	&Log("query: $query");
	$mib->{'error'} = $DBI::errstr;
	0;
    }
    else {
	$res;
    }
}


### ***-predicate() ###


sub AdminMemberP
{
    my ($mib, $addr) = @_;
    &__MemberP($mib, 'members-admin', $addr);
}


sub MemberP
{
    my ($mib, $addr) = @_;
    &__MemberP($mib, 'members', $addr);
}


sub ActiveP
{
    my ($mib, $addr) = @_;
    &__MemberP($mib, 'actives', $addr);
}


sub __MemberP
{
    my ($mib, $file, $addr) = @_;
    my ($query, $res, $ml, @row);

    $ml     = $mib->{'_ml_acct'};
    $query  = "select address from ml ";
    $query .= " where ml = '$ml' ";
    $query .= " and file = '$file' ";
    $query .= " and address = '$addr' ";

    ($res = &__Execute($mib, $query)) || return $NULL;

    @row = $res->fetchrow_array;
    &Log("row: @row") if $debug;

    $row[0] eq $addr ? 1 : 0;
}


### dump lists ###

sub GetActiveList { my($mib) = @_; &__DumpList($mib, 'actives', 1);}
sub GetMemberList { my($mib) = @_; &__DumpList($mib, 'members', 0);}
sub __DumpList
{
    my ($mib, $file, $ignore_off) = @_;
    my ($max, $orgf, $newf, $ml);
    my ($query);

    $ml     = $mib->{'_ml_acct'};
    $query  = " select address from ml ";
    $query .= " where ml = '$ml' ";
    $query .= " and file = '$file' ";
    if ($ignore_off) {
	$query .= " and off != '1' ";
    }

    # cache file to dump in
    $orgf = $mib->{'_cache_file'};
    $newf = $mib->{'_cache_file'}.".new.$$";

    if (open(OUT, "> $newf")) {
	my ($res, @row);

	($res = &__Execute($mib, $query)) || do {
	    close(OUT);
	    return $NULL;
	};

	while (@row = $res->fetchrow_array) { 
	    print OUT $row[0], "\n";
	}
	close(OUT);

	if (! rename($newf, $orgf)) {
	    &Log("ERROR: MySQL: cannot rename $newf $orgf");
	    $mib->{'error'} = "ERROR: MySQL: cannot rename $newf $orgf";
	}
    }
    else {
	&Log("ERROR: MySQL: cannot open $newf");
	$mib->{'error'} = "ERROR: MySQL: cannot open $orgf";
    }
}


### amctl ###
# subscribe unsubscribe 
sub __ListCtl
{
    my ($mib, $addr) = @_;
    my ($status);
    my ($ml, $query, $res);

    $addr = $addr || $mib->{'_address'};
    $ml   = $mib->{'_ml_acct'};

    &main::Log("$mib->{'_action'} $addr");

    if ($mib->{'_action'} eq 'subscribe' ||
	$mib->{'_action'} eq 'add') {

	$query  = " insert into ml ";
	$query .= " values ('$ml', 'actives', '$addr', 0, '$NULL') ";

	$query  = " insert into ml ";
	$query .= " values ('$ml', 'members', '$addr', 0, '$NULL') ";
	&__Execute($mib, $query) || return $NULL;

    }
    elsif ($mib->{'_action'} eq 'unsubscribe' ||
	   $mib->{'_action'} eq 'bye') {

	$query  = " delete from ml ";
	$query .= " where ml = '$ml' ";
	$query .= " and address = '$addr' ";
	&__Execute($mib, $query) || return $NULL;

    }
    elsif ($mib->{'_action'} eq 'off') {

	$query  = " update ml ";
	$query .= " set off = '1' ";
	$query .= " where ml = '$ml' ";
	$query .= " and file = 'actives' ";
	$query .= " and address = '$addr' ";
	&__Execute($mib, $query) || return $NULL;

    }
    elsif ($mib->{'_action'} eq 'on') {

	$query  = " update ml ";
	$query .= " set off = '0' ";
	$query .= " where ml = '$ml' ";
	$query .= " and file = 'actives' ";
	$query .= " and address = '$addr' ";
	&__Execute($mib, $query) || return $NULL;

    }
    elsif ($mib->{'_action'} eq 'chaddr') {

	my ($old_addr) = $mib->{'_old_address'};
	my ($new_addr) = $mib->{'_new_address'};

	for $file ('actives', 'members') {
	    $query  = " update ml ";
	    $query .= " set address = '$new_addr' ";
	    $query .= " where ml = '$ml' ";
	    $query .= " and file = '$file' ";
	    $query .= " and address = '$old_addr' ";
	    &__Execute($mib, $query) || return $NULL;
	}
    }
    elsif ($mib->{'_action'} eq 'digest' ||
	   $mib->{'_action'} eq 'matome') {

	my ($opt) = $mib->{'_value'};
	$query  = " update ml ";
	$query .= " set options = '$opt' ";
	$query .= " where ml    = '$ml' ";
	$query .= " and file    = 'actives' ";
	$query .= " and address = '$addr' ";
	&__Execute($mib, $query) || return $NULL;

    }
    elsif ($mib->{'_action'} eq 'addadmin') {

	$query  = " insert into ml ";
	$query .= " values ('$ml', 'members-admin', '$addr', 0, '$NULL') ";
	&__Execute($mib, $query) || return $NULL;

    }
    elsif ($mib->{'_action'} eq 'byeadmin') {

	$query  = " delete from ml ";
	$query .= " where ml = '$ml' ";
	$query .= " and file = 'members-admin' ";
	$query .= " and address = '$addr' ";
	&__Execute($mib, $query) || return $NULL;

    }
    else {
	&Log("ERROR: MySQL: unknown ACTION $mib->{'_action'}");
    }

    if ($mib->{'error'}) { return $NULL;}
}


sub Count
{
    my ($mib, $file) = @_;
    my ($mll, $query, $res);

    $ml     = $mib->{'_ml_acct'};
    $query  = " select count(address) from ml ";
    $query .= " where file = '$file' ";
    $query .= " and ml = '$ml' ";
    ($res = &__Execute($mib, $query)) || return $NULL;

    &Log($query) if $debug;
    @row = $res->fetchrow_array;
    $mib->{'_result'} = $row[0];
}


sub Status
{
    my ($mib, $file) = @_;
    my ($mll, $query, $res, $addr);

    $addr   = $mib->{'_address'};
    $ml     = $mib->{'_ml_acct'};
    $query  = " select address,off,options from ml ";
    $query .= " where file = 'actives' ";
    $query .= " and ml = '$ml' ";
    $query .= " and address = '$addr' ";
    ($res = &__Execute($mib, $query)) || return $NULL;

    &Log($query) if $debug;
    my ($a, $off, $option) = $res->fetchrow_array;

    $mib->{'_result'} .= "off "  if $off;
    $mib->{'_result'} .= $option if $option;
}


sub __Error
{
    my ($s) = @_;
    $mib->{'error'} = $s;
}


# for debug
sub RemoveAll
{
    my ($mib) = @_;
    &__Execute($mib, "drop table ml");
}


sub Dump
{
    my ($mib) = @_;
    my ($res);
    my (@row);

    print "---- table ml -----\n";
    $res = &__Execute($mib, "select * from ml order by file") ||
	return $NULL;
    while (@row = $res->fetchrow_array) { 
	printf "%-10s %-10s %-40s %-3d %s\n", @row;
    }
    print "--- end\n";
}


package main;
### debug mode ###
if ($0 eq __FILE__) {
    # debug routines
    eval "sub Log { print \@_, \"\\n\";}";

    # getopt()
    require 'getopts.pl';
    &Getopts("dh");

    my (%mib);
    $mib{'dbname'}   = $opt_D || 'fml';
    $mib{'host'}     = $opt_H || 'elena';
    $mib{'user'}     = $opt_U || $ENV{'USER'};
    $mib{'_ml_acct'} = 'elena';

    $MySQL::debug = 1;
    &MySQL::Init(\%mib);
    &MySQL::Dump(\%mib);
    &MySQL::Count(\%mib, 'actives');
    print "number of actives: ", $mib{'_result'}, "\n";
}


1;
