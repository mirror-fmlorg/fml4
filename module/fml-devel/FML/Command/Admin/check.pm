#-*- perl -*-
#
#  Copyright (C) 2002 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: check.pm,v 1.5 2002/09/24 14:23:12 fukachan Exp $
#

package FML::Command::Admin::check;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;
use FML::Log qw(Log LogWarn LogError);


=head1 NAME

FML::Command::Admin::check - checknostic

=head1 SYNOPSIS

See C<FML::Command> for more detaicheck.

=head1 DESCRIPTION

show user check(s).

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
sub need_lock { 0;}

my @rules =  qw(
		check_spool_dir
		check_html_archive_dir
		);


# Descriptions: checknostics
#    Arguments: OBJ($self) OBJ($curproc) HASH_REF($command_args)
# Side Effects: none
# Return Value: none
sub process
{
    my ($self, $curproc, $command_args) = @_;
    my $config = $curproc->{ config };

    for my $rule (@rules) {
	$self->$rule($curproc, $command_args);
    }
}


# Descriptions: check spool permission
#    Arguments: OBJ($self) OBJ($curproc) HASH_REF($command_args)
# Side Effects: fix permission
# Return Value: none
sub check_spool_dir
{
    my ($self, $curproc, $command_args) = @_;
    my $config    = $curproc->{ config };
    my $spool_dir = $config->{ spool_dir };

    #
    # 1. $spool_dir exists ?
    #
    print "spool_dir exists ? ... ";
    if (-d $spool_dir) {
	print "ok\n";
    }
    else {
	print "fail. not exist\n";
	-d $spool_dir || $curproc->($spool_dir, "mode=private");
	print "   created $spool_dir\n";
    }

    #
    # 2. $spool_dir permission should be 0700.
    #
    print "spool_dir permission ... ";
    print _is_700($spool_dir) ? "ok" : "fail";
    printf " (0%o)\n", _dir_mode($spool_dir);
}



# Descriptions: check html_archive permission
#    Arguments: OBJ($self) OBJ($curproc) HASH_REF($command_args)
# Side Effects: fix permission
# Return Value: none
sub check_html_archive_dir
{
    my ($self, $curproc, $command_args) = @_;
    my $config   = $curproc->{ config };
    my $html_dir = $config->{ html_archive_dir };

    print "html_archive_dir ... ";
    print _is_755($html_dir) ? "ok" : "fail";
    printf " (0%o)\n", _dir_mode($html_dir);
}


# Descriptions: return directory mode
#    Arguments: STR($dir)
# Side Effects: none
# Return Value: NUM(%o)
sub _dir_mode
{
    my ($dir) = @_;
    my ($dev,$ino,$mode) = stat($dir);

    return ($mode & 0777);
}


# Descriptions: check $dir mode is 0700
#    Arguments: STR($dir)
# Side Effects: none
# Return Value: NUM(1 or 0)
sub _is_700
{
    my ($dir) = @_;
    my $mode = _dir_mode($dir);

    my $smode = sprintf("%o", $mode);
    return ($smode eq '700' ? 1 : 0);
}


# Descriptions: check $dir mode is 0770
#    Arguments: STR($dir)
# Side Effects: none
# Return Value: NUM(1 or 0)
sub _is_770
{
    my ($dir) = @_;
    my $mode = _dir_mode($dir);

    my $smode = sprintf("%o", $mode);
    return ($smode eq '770' ? 1 : 0);
}


# Descriptions: check $dir mode is 0777
#    Arguments: STR($dir)
# Side Effects: none
# Return Value: NUM(1 or 0)
sub _is_777
{
    my ($dir) = @_;
    my $mode = _dir_mode($dir);

    my $smode = sprintf("%o", $mode);
    return ($smode eq '777' ? 1 : 0);
}


# Descriptions: check $dir mode is 0755
#    Arguments: STR($dir)
# Side Effects: none
# Return Value: NUM(1 or 0)
sub _is_755
{
    my ($dir) = @_;
    my $mode = _dir_mode($dir);

    my $smode = sprintf("%o", $mode);
    return ($smode eq '755' ? 1 : 0);
}


=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2002 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

FML::Command::Admin::check appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more detaicheck.

=cut


1;
