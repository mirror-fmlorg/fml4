#-*- perl -*-
#
#  Copyright (C) 2002 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: chaddr.pm,v 1.7 2002/09/11 23:18:07 fukachan Exp $
#

package FML::Command::Admin::chaddr;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;

=head1 NAME

FML::Command::Admin::chaddr - change the subscribed address

=head1 SYNOPSIS

See C<FML::Command> for more details.

=head1 DESCRIPTION

change address from old one to new one.

=head1 METHODS

=head2 C<process($curproc, $command_args)>

change address from old one to new one.

=cut


# Descriptions: standard constructor
#    Arguments: OBJ($self)
# Side Effects: none
# Return Value: OBJ
sub new
{
    my ($self) = @_;
    my ($type) = ref($self) || $self;
    my $me     = {};
    return bless $me, $type;
}


# Descriptions: need lock or not
#    Arguments: none
# Side Effects: none
# Return Value: NUM( 1 or 0)
sub need_lock { 1;}


# Descriptions: change address from old one to new one
#    Arguments: OBJ($self) OBJ($curproc) HASH_REF($command_args)
# Side Effects: update $member_map $recipient_map
# Return Value: none
sub process
{
    my ($self, $curproc, $command_args) = @_;
    my $config         = $curproc->{ config };
    my $member_maps    = $config->get_as_array_ref( 'member_maps' );
    my $recipient_maps = $config->get_as_array_ref( 'recipient_maps' );
    my $options        = $command_args->{ options };
    my $old_address    = '';
    my $new_address    = '';

    if (defined $command_args->{ command_data }) {
	my $x = $command_args->{ command_data };
	($old_address, $new_address) = split(/\s+/, $x);
    }
    else {
	$old_address = $options->[ 0 ];
	$new_address = $options->[ 1 ];
    }

    Log("chaddr: $old_address -> $new_address");

    # sanity check
    unless ($old_address && $new_address) {
	croak("chaddr: invalid arguments");
    }
    croak("\$member_maps is not specified")    unless $member_maps;
    croak("\$recipient_maps is not specified") unless $recipient_maps;

    use IO::Adapter;
    use FML::Credential;
    use FML::Log qw(Log LogWarn LogError);

    # change all maps
    my (@maps) = ();
    push(@maps, @$member_maps);
    push(@maps, @$recipient_maps);
    for my $map (@maps) {
	my $cred = new FML::Credential $curproc;

	# the current member/recipient file must have $old_address
	# but should not contain $new_address.
	if ($cred->has_address_in_map($map, $config, $old_address)) {
	    unless ($cred->has_address_in_map($map, $config, $new_address)) {
		# remove the old address.
		{
		    my $obj = new IO::Adapter $map, $config;
		    $obj->touch();

		    $obj->open();
		    $obj->delete( $old_address );
		    unless ($obj->error()) {
			Log("delete $old_address from map=$map");
		    }
		    else {
			croak("fail to delete $old_address to map=$map");
		    }
		    $obj->close();
		}

		# restart map to add the new address.
		# XXX we need to restart or rewrind map.
		{
		    my $obj = new IO::Adapter $map, $config;
		    $obj->open();
		    $obj->add( $new_address );
		    unless ($obj->error()) {
			Log("add $new_address to map=$map");
		    }
		    else {
			croak("fail to add $new_address to map=$map");
		    }
		    $obj->close();
		}
	    }
	    else {
		croak("$new_address is already member (map=$map)");
		return undef;
	    }
	}
    }
}


=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2002 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

FML::Command::Admin::chaddr first appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;