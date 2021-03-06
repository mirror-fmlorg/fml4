#-*- perl -*-
#
#  Copyright (C) 2001,2002,2003,2004 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: ThreadTrack.pm,v 1.29 2004/01/02 14:50:29 fukachan Exp $
#

package FML::CGI::ThreadTrack;
use strict;
use Carp;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use CGI qw/:standard/; # load standard CGI routines

use FML::Process::CGI;
@ISA = qw(FML::Process::CGI);


=head1 NAME

FML::CGI::ThreadTrack - CGI details to control thread system

=head1 SYNOPSIS

    $obj = new FML::CGI::ThreadTrack;
    $obj->prepare();
    $obj->verify_request();
    $obj->run();
    $obj->finish();

run() executes html_start(), run_cgi() and html_end() described below.

See L<FML::Process::Flow> for flow details.

=head1 DESCRIPTION

=head2 CLASS HIERARCHY

C<FML::CGI::ThreadTrack> is a subclass of C<FML::Process::CGI>.

=head1 METHODS

Almost methods common for CGI or HTML are forwarded to
C<FML::Process::CGI> base class.

=cut


# Descriptions: print out HTML header + body former part
#    Arguments: OBJ($curproc)
# Side Effects: none
# Return Value: none
sub html_start
{
    my ($curproc) = @_;
    my $config  = $curproc->config();
    my $title   = $config->{ thread_cgi_title }   || 'thread system interface';
    my $color   = $config->{ thread_cgi_bgcolor } || '#E6E6FA';
    my $myname  = $curproc->myname();
    my $charset = $curproc->get_charset("cgi");

    # o.k start html
    print start_html(-title   => $title,
		     -lang    => $charset,
		     -BGCOLOR => $color);
    print "\n";
}


# Descriptions: print out body latter part
#    Arguments: OBJ($curproc)
# Side Effects: none
# Return Value: none
sub html_end
{
    my ($curproc) = @_;

    # o.k. end of html
    print end_html;
    print "\n";
}


# Descriptions: main routine for thread control.
#               run_cgi() can process request: list, show, change_status
#    Arguments: OBJ($curproc)
# Side Effects: none
# Return Value: none
sub run_cgi_main
{
    my ($curproc) = @_;
    my $config = $curproc->config();
    my $myname = $config->{ program_name }; # XXX-TODO: valid ?
    my $ttargs = $curproc->_build_threadtrack_param();
    my $action = $curproc->safe_param_action() || '';

    use Mail::ThreadTrack;
    my $thread = new Mail::ThreadTrack $ttargs;

    if (defined $thread) {
	$thread->set_mode('html');

	if ($action eq 'list') {
	    $thread->summary();
	}
	elsif ($action eq 'show') {
	    my $id  = $curproc->safe_param_article_id();
	    # XXX-TODO: do not call _XXX() internal method from outside.
	    my $tid = $thread->_create_thread_id_strings($id);
	    $thread->show($tid);
	}
	elsif ($action eq 'change_status') {
	    # fmlthread.cgi is for administorator, so you can change status.
	    if ($myname eq 'fmlthread.cgi') {
		my $list = $curproc->safe_paramlist2_threadcgi_change_status();
		for my $param (@$list) {
		    my ($ml, $id, $value) = @$param;
		    if ($value eq 'closed') {
			my $tid = $thread->_create_thread_id_strings($id);
			print "closed $tid", br, "\n";
			$thread->close($tid);
		    }
		}
	    }
	    # XXX-TODO: ? clarify this message more.
	    else {
		print "Warning: only administrator change status\n";
	    }

	    $thread->summary();
	}
	else {
	    $thread->summary();
	}
    }
    else {
	croak("fail to create thread object");
    }
}


# Descriptions: prepare basic parameters for Mail::ThreadTrack module
#    Arguments: OBJ($curproc)
# Side Effects: none
# Return Value: HASH_REF
sub _build_threadtrack_param
{
    my ($curproc) = @_;
    my $config = $curproc->config();
    my $myname = $config->{ program_name };
    my $option = $curproc->command_line_options();

    # prepare arguments for thread track module
    # XXX-TODO: hmm, we should provide $curproc->util->article_max_id() ?
    my $ml_name       = $curproc->safe_param_ml_name();
    my $thread_db_dir = $config->{ thread_db_dir };
    my $spool_dir     = $config->{ spool_dir };
    my $max_id        = $curproc->article_max_id();
    my $ttargs        = {
	myname        => $myname,
	logfp         => \&Log,
	fd            => \*STDOUT,
	db_base_dir   => $thread_db_dir,
	ml_name       => $ml_name,
	spool_dir     => $spool_dir,
	reverse_order => 0,
    };

    # import some variables
    for my $varname (qw(base_url msg_base_url)) {
	if (defined $option->{ $varname }) {
	    $ttargs->{ $varname } = $option->{ $varname };
	}
	elsif (defined $config->{ $varname }) {
	    $ttargs->{ $varname } = $config->{ $varname };
	}
    }

    return $ttargs;
}


# Descriptions: print navigation bar
#    Arguments: OBJ($curproc)
# Side Effects: none
# Return Value: none
sub run_cgi_navigator
{
    my ($curproc) = @_;
    my $config  = $curproc->config();
    my $action  = $curproc->safe_cgi_action_name();
    my $target  = $config->{ thread_cgi_target_window } || '_top';
    # XXX-TODO: we should provide $curproc->util->get_ml_list() method ?
    my $ml_list = $curproc->get_ml_list();
    my $ml_name = $config->{  ml_name };

    print start_form(-action=>$action, -target=>$target);

    print "ML: ";
    print popup_menu(-name   => 'ml_name', -values => $ml_list);
    print "<BR>\n";

    print "orderd by: ";
    my $order = [ 'cost', 'date', 'reverse date' ];
    print popup_menu(-name   => 'order', -values => $order );
    print "<BR>\n";

    print submit(-name => 'change target');
    print reset(-name => 'reset');

    print end_form;
    print "<HR>\n";
}


=head1 SEE ALSO

L<CGI>,
L<FML::Process::CGI>
and
L<FML::Process::Flow>

=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2001,2002,2003,2004 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

FML::CGI::ThreadTrack first appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;
