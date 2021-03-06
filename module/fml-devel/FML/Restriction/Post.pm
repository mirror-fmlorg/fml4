#-*- perl -*-
#
#  Copyright (C) 2003,2004 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: Post.pm,v 1.9 2004/01/21 03:40:44 fukachan Exp $
#

package FML::Restriction::Post;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;
use FML::Log qw(Log LogWarn LogError);


=head1 NAME

FML::Restriction::Post - restricts who is allowed to post/use command mails.

=head1 SYNOPSIS

collection of utility functions used in post routines.

=head1 DESCRIPTION

=head1 METHODS

=cut


# Descriptions: constructor.
#    Arguments: OBJ($self) OBJ($curproc)
# Side Effects: none
# Return Value: OBJ
sub new
{
    my ($self, $curproc) = @_;
    my ($type) = ref($self) || $self;
    my $me     = { _curproc => $curproc };
    return bless $me, $type;
}


# Descriptions: reject if $sender matches a system account.
#    Arguments: OBJ($self) STR($rule) STR($sender)
# Side Effects: none
# Return Value: ARRAY(STR, STR)
sub reject_system_special_accounts
{
    my ($self, $rule, $sender) = @_;
    my $curproc = $self->{ _curproc };
    my $cred    = $curproc->{ credential };
    my $match   = $cred->match_system_special_accounts($sender);
    my $pcb     = $curproc->pcb();

    if ($match) {
	$curproc->log("${rule}: $match matches sender address");
	unless ($pcb->get("check_restrictions", "deny_reason")) {
	    $pcb->set("check_restrictions", "deny_reason", $rule);
	}
	return("matched", "deny");
    }

    return(0, undef);
}


# Descriptions: [BACKWARD COMPATIBILITY]
#               reject if $sender matches a system account.
#    Arguments: OBJ($self) STR($rule) STR($sender)
# Side Effects: none
# Return Value: ARRAY(STR, STR)
sub reject_system_accounts
{
    my ($self, $rule, $sender) = @_;
    $self->reject_system_special_accounts($rule, $sender);
}


# Descriptions: permit irrespective of $sender :)
#    Arguments: OBJ($self) STR($rule) STR($sender)
# Side Effects: none
# Return Value: ARRAY(STR, STR)
sub permit_anyone
{
    my ($self, $rule, $sender) = @_;

    return("matched", "permit");
}


# Descriptions: permit if $sender is an ML member.
#    Arguments: OBJ($self) STR($rule) STR($sender)
# Side Effects: none
# Return Value: ARRAY(STR, STR)
sub permit_member_maps
{
    my ($self, $rule, $sender) = @_;
    my $curproc = $self->{ _curproc };
    my $cred    = $curproc->{ credential };
    my $pcb     = $curproc->pcb();

    # Q: the mail sender is a ML member?
    if ($cred->is_member($sender)) {
	# A: Yes, we permit to distribute this article.
	return("matched", "permit");
    }
    else {
	# A: No, deny distribution
	$curproc->logerror("$sender is not an ML member");
	$curproc->logerror( $cred->error() );

	# reply this info in each FML::Process::* module.
	# $curproc->reply_message_nl('error.not_member',
	#			   "you are not a ML member." );
	# $curproc->reply_message( "   your address: $sender" );

	# save reason for later use.
	unless ($pcb->get("check_restrictions", "deny_reason")) {
	    $pcb->set("check_restrictions", "deny_reason", $rule);
	}

	# XXX "deny ASAP if this method fails." ? NO, wrong!
	# XXX permit_XXX() allows the trial match of another rules.
	# return("matched", "deny");
    }

    return(0, undef);
}


#
# XXX-TODO: permit_commands_for_stranger -> permit_anonymous_command ?
#


# Descriptions: permit this command even if $sender is a stranger.
#    Arguments: OBJ($self) STR($rule) STR($sender)
# Side Effects: none
# Return Value: ARRAY(STR, STR)
sub permit_commands_for_stranger
{
    my ($self, $rule, $sender) = @_;
    my $curproc = $self->{ _curproc };
    my $pcb     = $curproc->pcb();

    # XXX-TODO: find_commands_for_stranger -> match_anonymous_command ?
    use FML::Command::DataCheck;
    my $check = new FML::Command::DataCheck;
    if ($check->find_commands_for_stranger($curproc)) {
	$curproc->log("$rule matched. accepted.");
	return("matched", "permit");
    }

    return(0, undef);
}


# Descriptions: reject irrespective of $sender.
#    Arguments: OBJ($self) STR($rule) STR($sender)
# Side Effects: none
# Return Value: ARRAY(STR, STR)
sub reject
{
    my ($self, $rule, $sender) = @_;
    my $curproc = $self->{ _curproc };
    my $pcb     = $curproc->pcb();

    unless ($pcb->get("check_restrictions", "deny_reason")) {
	$pcb->set("check_restrictions", "deny_reason", $rule);
    }
    return("matched", "deny");
}


=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2003,2004 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

FML::Restriction::Post first appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;
