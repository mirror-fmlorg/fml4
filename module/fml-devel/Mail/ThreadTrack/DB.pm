#-*- perl -*-
#
#  Copyright (C) 2001,2002,2003 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: DB.pm,v 1.34 2003/08/23 15:33:17 fukachan Exp $
#

package Mail::ThreadTrack::DB;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;

my $debug = 0;

=head1 NAME

Mail::ThreadTrack::DB - database access.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=cut

=head2 db_open()

open database.
It uses tie() to bind a hash to a DB file.
Our thread model uses several DB files such as
C<%thread_id>,
C<%date>,
C<%status>,
C<%sender>,
C<%articles>,
C<%message_id>
and
C<%index>.

=head2 db_close()

untie() the corresponding hashes opened by C<db_open()>.

=cut

my @kind_of_databases = qw(thread_id date status sender articles
                           message_id);


# Descriptions: open database by tie()
#    Arguments: OBJ($self)
# Side Effects: $self->{ _hash_table } initialized.
# Return Value: none
sub db_open
{
    my ($self) = @_;
    my $db_type   = $self->{ config }->{ db_type } || 'AnyDBM_File';
    my $db_dir    = $self->{ _db_dir };
    my $file_mode = $self->{ _file_mode } || 0644;

    use File::Spec;
    eval qq{ use $db_type; use Fcntl;};
    unless ($@) {
        for my $db (@kind_of_databases) {
	    my $file = File::Spec->catfile($db_dir, $db);
            my $str  = qq{
                my \%$db = ();
                tie \%$db, \$db_type, \$file, O_RDWR|O_CREAT, $file_mode;
                \$self->{ _hash_table }->{ _$db } = \\\%$db;
            };
            eval $str;
            croak($@) if $@;
        }

	my %index      = ();
	my $index_file = $self->{ _index_db };
	eval q{
	    tie %index, $db_type, $index_file, O_RDWR|O_CREAT, $file_mode;
	    $self->{ _hash_table }->{ _index } = \%index;
	};
	croak($@) if $@;
    }
    else {
        croak("failed to \"use $db_type\"");
    }

    1;
}


# Descriptions: clear database
#    Arguments: OBJ($self)
# Side Effects: update database
# Return Value: none
sub db_clear
{
    my ($self) = @_;
    my $db_dir = '';

    $db_dir = $self->{ _db_dir };
    _db_clear($db_dir) if -d $db_dir;

    $db_dir = $self->{ _db_base_dir };
    _db_clear($db_dir) if -d $db_dir;
}


# Descriptions: clear database
#    Arguments: STR($db_dir)
# Side Effects: clear database, remove file if needed
# Return Value: none
sub _db_clear
{
    my ($db_dir) = @_;

    eval q{
	use DirHandle;
	use File::Spec;
	my $dh = new DirHandle $db_dir;

	if (defined $dh) {
	    my $f = '';
	    while (defined($f = $dh->read)) {
		next if $f =~ /^\./;
		my $file = File::Spec->catfile($db_dir, $f);
		if (-f $file) {
		    unlink $file;
		    print STDERR "removed $file\n" unless -f $file;
		}
	    }
	    $dh->close;
	}
    };
    croak($@) if $@;
}


# Descriptions: close database by untie()
#    Arguments: OBJ($self)
# Side Effects: none
# Return Value: none
sub db_close
{
    my ($self) = @_;

    for my $db (@kind_of_databases) {
        my $str = qq{
            my \$${db} = \$self->{ _hash_table }->{ _$db };
	    untie \%\$${db};
        };
        eval $str;
        croak($@) if $@;
    }

    my $index = $self->{ _hash_table }->{ _index };
    untie %$index;
}


=head2 db_mkdb($min, $max)

remake database.

=cut


# Descriptions: remake database for messages from $min_id to $max_id
#    Arguments: OBJ($self) NUM($min_id) NUM($max_id)
# Side Effects: remake database
# Return Value: none
sub db_mkdb
{
    my ($self, $min_id, $max_id) = @_;
    my $config     = $self->{ _config };
    my $spool_dir  = $config->{ spool_dir };
    my $saved_args = $self->{ _saved_args }; # original $args

    return undef unless (defined $min_id && defined $max_id);

    use Mail::Message;
    use File::Spec;

    my $count = 0;
    my ($fh, $file, $msg);
    print STDERR "db_mkdb: $min_id -> $max_id\n" if $debug;

  ID:
    for my $id ( $min_id .. $max_id ) {
	print STDERR "." if $count++ % 10 == 0;
	print STDERR "process $id\n" if $debug;

	# XXX-TODO: this code is workaround, we should create more clever way.
	# XXX-TODO: overwrite (tricky)
	$self->{ _config }->{ article_id } = $id;

	# parse article and analyze it.
	$file = $self->filepath({
	    base_dir => $spool_dir,
	    id       => $id,
	});

	$fh = new FileHandle $file;
	if (defined $fh) {
	    my $msg  = Mail::Message->parse({ fd => $fh });
	    $self->analyze($msg);

	    # XXX-TODO: workaround, we should create more clever way.
	    # XXX-TODO: remove current status (tricky ;)
	    delete $self->{ _status };
	}
    }
    print STDERR "\n" if $count > 0;
}


=head2 db_dump([$type])

dump hash as text.
dump status database if $type is not specified.

=cut


# Descriptions: dump data for database $type
#    Arguments: OBJ($self) STR($type)
# Side Effects: none
# Return Value: none
sub db_dump
{
    my ($self, $type) = @_;
    my $db_type = "_" . ( defined $type ? $type : 'status' );
    my $rh      = $self->{ _hash_table }->{ $db_type };

    my ($k, $v);
    while (($k, $v) = each %$rh) {
	printf "%-20s %s\n", $k, $v;
    }
}


=head2 db_hash( $type )

return HASH REFERENCE for specified database $type.

=cut


# Descriptions: get HASH REFERENCE for specified $type.
#    Arguments: OBJ($self) STR($db_type)
# Side Effects: none
# Return Value: HASH_REF or UNDEF
sub db_hash
{
    my ($self, $db_type) = @_;
    my $type = "_" . $db_type;

    if (defined $self->{ _hash_table }->{ $type }) {
	return $self->{ _hash_table }->{ $type };
    }
    else {
	return undef;
    }
}


=head2 db_last_modified()

return the last modified time of our dateabase as unix time.
This time is the latest modified time among all database files.

=cut


# Descriptions: return the last modified time (unix time) of database
#    Arguments: OBJ($self) STR($db_type)
# Side Effects: none
# Return Value: STR or UNDEF
sub db_last_modified
{
    my ($self, $db_type) = @_;
    my $db_dir        = $self->{ _db_dir };
    my $last_modified = 0;

    # XXX-TODO: we supporse Berkeley DB. fix it.
    use File::Spec;
    my $file = File::Spec->catfile($db_dir, "date.db");
    if (-f $file) {
	$last_modified = (stat($file))[8];
    }

    return $last_modified;
}


=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2001,2002,2003 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

Mail::ThreadTrack::DB first appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;
