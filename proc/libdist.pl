# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;


sub DoDistribute
{
    local(*e) = @_;

    $0 = "$FML: Distributing <$LOCKFILE>";
    local($status, $s, $id);

    # DECLARE: Global Rcpt Lists; and the number of recipients;   
    @Rcpt = (); $Rcpt = 0;

    $DISTRIBUTE_START_HOOK && 
	&eval($DISTRIBUTE_START_HOOK, 'Distribute Start hook'); 

    ### declare distribution mode (see libsmtp.pl) # (preamble, trailer);
    $e{'mode:dist'} = 1;

    ##### ML Preliminary Session Phase 01: set and save ID
    # Get the present ID
    &Open(IDINC, $SEQUENCE_FILE) || return; # test
    $ID = &GetFirstLineFromFile($SEQUENCE_FILE);
    $ID++;			# increment, GLOBAL!

    # ID = ID + 1 (ID is a Count of ML article)
    &Write2($ID, $SEQUENCE_FILE) || return;

    # wait for sync against duplicated ID for slow IO or broken calls
    {
	local($newid, $waitc);
	while (1) {
	    $newid = &GetFirstLineFromFile($SEQUENCE_FILE);
	    last if $newid == $ID;
	    last if $waitc++ > 10;
	    sleep 1;
	}

	&Log("FYI: $waitc secs for \$SEQUENCE_FILE sync") if $waitc > 1;

	# to fix duplicated ID's; ?(but how we can detect all cases)
	# if (-f "$FP_SPOOL_DIR/$ID") { &use('er'); &FixID;}
    }

    ##### ML Preliminary Session Phase 02: $DIR/summary
    # save summary and put log
    $s = $e{'h:Subject:'};
    $s =~ s/\n(\s+)/$1/g;

    # MIME decoding. 
    # If other fields are required to decode, add them here.
    # c.f. RFC1522	2. Syntax of encoded-words
    if ($e{'MIME'}) { &use('MIME'); $s = &DecodeMimeStrings($s);}

    # fml-support: 02007
    $s =~ s/^\s*//; # required???
    &Append2(sprintf("%s [%d:%s] %s", 
		     $Now, $ID, substr($From_address, 0, 15), $s),
	     $SUMMARY_FILE) || return;

    # Original is for 5.67+1.6W, but R8 requires no MX tuning tricks.
    # So version 0 must be forever(maybe) :-)
    # RMS = Relay, Matome, Skip; C = Crosspost;
    $Rcsid =~ s/^(.*)(\#\d+\s+.*)/$1.($USE_CROSSPOST?"(rmsc)":"(rms)").$2/e;
    $Rcsid =~ s/\)\(/,/g;

    # plural active_list available (97/03/26)
    # Global Rcpt is already initialized;
    # Set @Rcpt if not DLA; usually (in DLA), only scan [mrs]= options;
    {
	local(@a) = (@ACTIVE_LIST, $ACTIVE_LIST); 
	&Uniq(*a); # here uniqed
	for (@a) { &ReadActiveRecipients($_);}
    }

    ##### ML Distribute Phase 01: Fixing and Adjusting *Header
    # Run-Hooks. when you require to change header fields...
    $SMTP_OPEN_HOOK && &eval($SMTP_OPEN_HOOK, 'SMTP_OPEN_HOOK:');

    # set Reply-To:, use "ORIGINAL Reply-To:" if exists ??? (96/2/18, -> Reply)
    $e{'h:Reply-To:'} = 
	$e{'fh:reply-to:'} || $e{'h:Reply-To:'} || $MAIL_LIST;

    # get ID (the current sequence of the Mailing List)
    $id = sprintf("%05d", $ID);		# 96/05/07 set $id here for each mode 

    # Subject ReConfigure;
    { 
	local($pat);
	local($subject) = $e{'h:Subject:'} || $Subject; # original
	$subject =~ s/^\s*//;

	if ($SUBJECT_HML_FORM) {# FIX (95/07/03) kise@ocean.ie.u-ryukyu.ac.jp;
	    if ($HML_FORM_LONG_ID || $SUBJECT_FORM_LONG_ID) {
		$id = &LongId($ID, $HML_FORM_LONG_ID || $SUBJECT_FORM_LONG_ID);
	    }
	    $e{'h:Subject:'} = "[$BRACKET:$id] $subject";
	}
	elsif ($SUBJECT_FREE_FORM) {
	    if ($SUBJECT_FORM_LONG_ID) {
		$id = &LongId($ID, $SUBJECT_FORM_LONG_ID);
	    }

	    if ($BRACKET_SEPARATOR ne '') {
		$pat = $BEGIN_BRACKET.$BRACKET.$BRACKET_SEPARATOR.$id.$END_BRACKET;
	    }
	    else {
		$pat = $BEGIN_BRACKET.$BRACKET.$END_BRACKET;
	    }


	    $e{'h:Subject:'} = "$pat $subject";
	}
    }

    # Run-Hooks
    $HEADER_ADD_HOOK && &eval($HEADER_ADD_HOOK, 'Header Add Hook');

    # Message ID: e.g. 199509131746.CAA14139@axion.phys.titech.ac.jp
    # 95/09/14 add the fml Message-ID for more powerful loop check
    # /etc/sendmail.cf H?M?Message-Id: <$t.$i@$j>
    # <>fix by hyano@cs.titech.ac.jp 95/9/29
    # e.g. for the change of $e{'h:Message-Id:'} in HOOK...
    if (! $USE_ORIGINAL_MESSAGE_ID) {
	$e{'h:Message-Id:'}  = 
	    ($e{'h:Message-Id:'} ne $e{'h:message-id:'}) ?
		$e{'h:Message-Id:'} : &GenMessageId;
 	&Append2($e{'h:Message-Id:'}, $LOG_MESSAGE_ID);
    }
		      
    # STAR TREK SUPPORT:-);
    if ($APPEND_STARDATE) { &use('stardate'); $e{'h:X-Stardate:'} = &Stardate;}

    # Server info to add
    $e{'h:X-MLServer:'}  = $Rcsid if $Rcsid;
    $e{'h:X-MLServer:'} .= "\n\t($rcsid)" if $debug && $rcsid;
    $e{"h:$XMLCOUNT:"}   = $id || sprintf("%05d", $ID); # 00010;
    $e{"h:X-ML-Info:"}   = &GenXMLInfo;

    ##### ML Distribute Phase 02: Generating Hdr
    # This is the order recommended in RFC822, p.20. But not clear about X-*
    local(%dup);
    for (@HdrFieldsOrder) {
	&Debug("DoDistribute:DUP FIELD\t$_") if $dup{$_} && $debug;
	next if $dup{$_}; $dup{$_} = 1; # duplicate check;

	# for more readability
	$e{"h:$_:"} =~ s/^(\S)/ $1/;

	# print STDERR "\$e{'h:$_:'}\t". $e{"h:$_:"} ."\n";
	$lcf = $_; $lcf =~ tr/A-Z/a-z/; # lower case field name

	if ($e{"fh:$lcf:"}) {	# force some value to a field
	    $e{'Hdr'} .= "$_: ". $e{"fh:$lcf:"} ."\n";
	}
	elsif ($e{"oh:$lcf:"}) { # original fields
	    $e{'Hdr'} .= "$_:". $e{"h:$lcf:"} ."\n" if $e{"h:$lcf:"};
	}
	elsif (/^:body:$/o && $body) {
	    $e{'Hdr'} .= $body;
	}
	elsif (/^:any:$/ && $e{'Hdr2add'}) {
	    $e{'Hdr'} .= $e{'Hdr2add'};
	}
	# ALREADY EXIST?
	elsif (/^Message\-Id/i && ($body =~ /Message\-Id:/i)) { 
	    ;
	}
	elsif (/^:XMLNAME:$/o) {
	    $e{'Hdr'} .= "$XMLNAME\n";
	}
	elsif (/^:XMLCOUNT:$/o) {
	    $e{'Hdr'} .= "$XMLCOUNT: $e{\"h:$XMLCOUNT:\"}\n";
	}
	elsif ($e{"h:$_:"}) {
	    $e{'Hdr'} .= "$_:".($e{"fh:$lcf:"} || $e{"h:$_:"})."\n";
	}
    }

    # fixing;
    $e{'Hdr'} =~ s/[\s\n]*$/\n/;

    ##### ML Distribute Phase 03: Spooling
    # spooling, check dupulication of ID against e.g. file system full
    # not check the return value, ANYWAY DELIVER IT!
    # IF THE SPOOL IS MIME-DECODED, NOT REWRITE %e, so reset %me <- %e;
    # 
    local($umask) = umask(027) if $USE_FML_WITH_FMLSERV;

    if ($NOT_USE_SPOOL) {
	;
    }
    elsif (! -f "$FP_SPOOL_DIR/$ID") {	# not exist
	&Log("ARTICLE $ID");
	&Write3(*e, "$FP_SPOOL_DIR/$ID");
    } 
    else { # if exist, warning and forward againt DISK-FULL;
	&Log("ARTICLE $ID", "ID[$ID] dupulication");
	&Append2("$e{'Hdr'}\n$e{'Body'}", "$FP_VARLOG_DIR/DUP$CurrentTime");
	&Warn("ERROR:ARTICLE ID dupulication $ML_FN", 
	      "Try save > $FP_VARLOG_DIR/DUP$CurrentTime\n$e{'Hdr'}\n$e{'Body'}");
    }

    umask($umask) if $USE_FML_WITH_FMLSERV;

    ##### ML Distribute Phase 04: SMTP
    # IPC. when debug mode or no recipient, no distributing 
    &Deliver;
}


sub ReadActiveRecipients
{
    local($active) = @_;

    &Log("ReadActiveRecipients:$active") if $debug_active;

    ##### ML Preliminary Session Phase 03: get @Rcpt
    &Open(ACTIVE_LIST, $active) || return 0;

    # Under DLA_HACK PreProcessing Section;
    # Get a member list to deliver
    # After 1.3.2, inline-code is modified for further extentions.
    {
	local($rcpt, $lc_rcpt, $opt, $w, $relay);
	local($who, $domain, $mxhost, $k, $v);

	# default setting %SKIP and compat (obsolete %Skip);
	# append something to the current %SKIP;
	for $k (keys %Skip) { $k =~ tr/A-Z/a-z/; $SKIP{$_} = 1;}

	for ($MAIL_LIST, $CONTROL_ADDRESS) {
	    $k = $_; $k =~ tr/A-Z/a-z/; $SKIP{$k} = 1;
	    ($who) = split(/\@/, $_);
	    $k = "$who\@$DOMAINNAME"; $k =~ tr/A-Z/a-z/; $SKIP{$k} = 1;
	    $k = "$who\@$FQDN";   $k =~ tr/A-Z/a-z/; $SKIP{$k} = 1;
	}

      line: while (<ACTIVE_LIST>) {
	  chop;

	  next line if /^\#/o;	 # skip comment and off member
	  next line if /^\s*$/o; # skip null line

	  # strip comment, not \S+ for mx;
	  s/(\S+)\s+\#.*$/$1/;

	  # Backward Compatibility; tricky "^\s".Code above need no /^\#/o;
	  s/\smatome\s+(\S+)/ m=$1 /i;
	  s/\sskip\s*/ s=skip /i;

	  ($rcpt, $opt) = split(/\s+/, $_, 2);
	  $opt = ($opt && !($opt =~ /^\S=/)) ? " r=$opt " : " $opt ";

	  $lc_rcpt = $rcpt;
	  $lc_rcpt =~ tr/A-Z/a-z/; # lower case;

	  printf STDERR "%-30s %s\n", $rcpt, $opt if $debug;

	  next line if $opt =~ /\s[ms]=/i;	# tricky "^\s";
	  next line if $SKIP{$lc_rcpt}; # SKIP FIELD;

	  # Relay server (RFC821 syntax 97/02/01)
	  # % relay hack is not refered in RFC, but effective in Sendmail's;
	  if ($opt =~ /\sr=(\S+)/i || $DEFAULT_RELAY_SERVER) {
	      $relay = $1 || $DEFAULT_RELAY_SERVER;
	      # % hack
	      #($who, $mxhost) = split(/@/, $rcpt, 2);
	      # DLA_HACK: $rcpt is original "addr" in ACTIVE_LIST;
	      # $RelayRcpt{$rcpt} = "${who}\%${mxhost}\@${relay}";
	      # $rcpt = "${who}\%${mxhost}\@${relay}";
	      # "Key" of %RclayRcpt is lower case for convenice;
	      $RelayRcpt{$lc_rcpt} = "\@${relay}:$rcpt";
	      $rcpt = "\@${relay}:$rcpt";
	  }

	  $Rcpt++; # count the number of recipients;
      }

	close(ACTIVE_LIST);
    }
}


# Thoreticaly all file IO have been done and needed info are on the memory.
# So we must be able to do UNLOCK our current process.
sub Deliver
{
    local($status, $smtp_time);
    
    if ($debug) {
	&Log("DEBUG MODE: NO DELIVER rcpt=[$Rcpt] debug=[$debug]");
	return 1;
    }

    if ($Rcpt == 0) { return;} # NO RCPT

    $Envelope{'mode:_Deliver'} = 1; # notify the &Smtp deliver mode;

    $smtp_time = time;
    $status = &Smtp(*Envelope, *Rcpt);
    &Log("Smtp:$status") if $status;
    &StatDelivery($smtp_time, $Rcpt) if $debug_stat;

    undef $Envelope{'mode:_Deliver'};

    ##### ML Distribute Phase 05: ends
    $DISTRIBUTE_CLOSE_HOOK .= $SMTP_CLOSE_HOOK;
    if ($DISTRIBUTE_CLOSE_HOOK) {
	&eval($DISTRIBUTE_CLOSE_HOOK, 'Distribute close Hook');
    }
}

sub StatDelivery
{
    local($smtp_time, $nrcpt) = @_;

    $smtp_time = time - $smtp_time;
    $pdt = $smtp_time/$nrcpt;
    &Log("Delivery Stat[$ID]: ${smtp_time}/${nrcpt} = ${pdt} sec./rcpts");
}

sub GenXMLInfo
{
    if ($X_ML_INFO_MESSAGE) { 
	$X_ML_INFO_MESSAGE;
    }
    elsif (!$CONTROL_ADDRESS && 
	   $PERMIT_POST_FROM =~ /^(anyone|members_only)$/) {
	"If you have a question,\n\tplease make a contact with $MAINTAINER";
    }
    else {
	"If you have a question, send a mail with the body\n".
	    "\t\"\# help\" (without quotes) to the address ". &CtlAddr;
    }
}

# return Long ID FORM
sub LongId
{
    local($id, $howlong) = @_;
    local($s);

    if ($howlong > 0) {
	$howlong = $howlong < 2 ? 5 : $howlong; # default is 5;
	$s = "\$id = sprintf(\"%0". $howlong. "d\", $id);";
	eval $s;
    }

    $id;
}

1;
