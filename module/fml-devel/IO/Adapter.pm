#-*- perl -*-
#
#  Copyright (C) 2001,2002,2003,2004 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: Adapter.pm,v 1.29 2004/02/03 04:15:32 fukachan Exp $
#

package IO::Adapter;
use vars qw(@ISA @ORIG_ISA $FirstTime $AUTOLOAD);
use strict;
use Carp;
use IO::Adapter::ErrorStatus qw(error_set error error_clear);

my $debug = 0;

# prepare error_set() is called
@ISA = qw(IO::Adapter::ErrorStatus);

BEGIN {}
END   {}

=head1 NAME

IO::Adapter - adapter for several IO interfaces

=head1 SYNOPSIS

    use IO::Adapter;
    $obj = new IO::Adapter ($map, $map_params);
    $obj->open || croak("cannot open $map");
    while ($x = $obj->getline) { ... }
    $obj->close;

where C<$map_params> is map specific parameters used for such as C<RDBMS>.
For example, C<$map_params> is:

    $map_params = {
	'mysql:toymodel' => {
	    sql_server     => 'mysql.fml.org',
	    database       => 'fml',
	    table          => 'ml',
	    user           => 'fml',
	    user_password  => "secret password :)",

	    # model specific driver module
	    driver         => 'My::Driver::Module::Name',
	},
    };

where you can specify your own module to provide specific SQL
statements.

=head1 DESCRIPTION

This is "Adapter" (or "Wrapper") C<design pattern>.
This is a wrapper of IO for
e.g. file,
unix group,
NIS (Network Information System),
RDBMS (Relational DataBase Management System)
et. al.
Once you create and open a C<map>,
you can use the same methods as usual file IO.

=head2 DATA STRUCTURE

Consider file with space separators. The data structure in a file
is described like this:

	file content = {
		key1 => undef,
		key2 => [ value2 ],
		key3 => [ value3a, value3b ],
	};

IO::Adapter converts data in arbitrary map e.g. file, /etc/group,
RDBMS into this structure described above.
Also,
IO::Adapter provides unified access methods to this structure.


Instead of unification, IO::Adapter may provide amibugous IO.
For example, IO into array is not described as above.
/etc/group must be described as

	wheel group = {
		"root" => undef,
		key2   => undef,
		key3   => undef,
	};


=head2 MAP

C<map> specifies the type of the database we read/write.

For example, C<file> map implies we hold our data in a file.
The format is one line for one entry in a lot of cases.

   key1
   key2 value

To get one entry is to read one line or a part of one line.

This wrapper provides IO like a usual file for the specified C<$map>.

=head2 MAP TYPES

   map name        descriptions or examples
   ---------------------------------------------------
   file            file:$file_name
                   For example, file:/var/spool/ml/elena/recipients

   unix.group      unix.group:$group_name
                   For example, unix.group:fml

   nis.group       nis.group:$group_name
                   the NIS "Netork Information System" (YP) map "group.byname"
                   For example, nis.group:fml

   mysql           mysql:$schema_name

   postgresql      postgresql:$schema_name
                   *** not yet implemented ***

   ldap            ldap:$schema_name
                   *** not yet implemented ***

=head1 METHODS

=item C<new($map, $args)>

the constructor. The first argument is a map decribed above.

=cut


# Descriptions: a constructor, which prepare IO operations for the
#               given $map.
#    Arguments: OBJ($self) STR($map) HASH_REF($args)
# Side Effects: @ISA is modified
#               load and import sub-class
# Return Value: OBJ
sub new
{
    my ($self, $map, $args) = @_;
    my ($type) = ref($self) || $self;
    my ($me)   = { _map => $map };
    my ($pkg, @pkg);

    # 2002/07/22: accpet READ_ONLY($map).
    if ($map =~ /^READ_ONLY\(/) {
	$map =~ s/^READ_ONLY\(//;
	$map =~ s/^\)$//;
	$me->{ _hints }->{ read_only } = 1;
    }
    else {
	$me->{ _hints }->{ read_only } = 0;
    }

    if (ref($map) eq 'ARRAY') {
	$pkg                    = 'IO::Adapter::Array';
	$me->{_type}            = 'array_reference';
	$me->{_array_reference} = $map;
    }
    else {
	if ($map =~ /file:(\S+)/ || $map =~ m@^(/\S+)@) {
	    $me->{_file} = $1;
	    $me->{_type} = 'file';
	    $pkg         = 'IO::Adapter::File';
	}
	elsif ($map =~ /unix\.group:(\S+)/) {
	    $me->{_name} = $1;
	    $me->{_type} = 'unix.group';
	    $pkg         = 'IO::Adapter::UnixGroup';
	}
	elsif ($map =~ /nis\.group:(\S+)/) {
	    $me->{_name} = $1;
	    $me->{_type} = 'nis.group';
	    $pkg         = 'IO::Adapter::NIS';
	}
	elsif ($map =~ /(mysql|postgresql):(\S+)/i) {
	    $me->{_type}   = $1;
	    $me->{_schema} = $2;
	    $me->{_params} = $args;
	    $me->{_type}   =~ tr/A-Z/a-z/; # lowercase the '_type' syntax
	    $pkg           = 'IO::Adapter::MySQL';
	    @pkg           = qw(IO::Adapter::DBI);
	}
	elsif ($map =~ /(ldap):(\S+)/i) {
	    $me->{_type}   = $1;
	    $me->{_schema} = $2;
	    $me->{_params} = $args;
	    $me->{_type}   =~ tr/A-Z/a-z/; # lowercase the '_type' syntax
	    $pkg           = 'IO::Adapter::LDAP';
	}
	else {
	    my $s = "IO::Adapter::new: map='$map' is unknown.";
	    error_set($me, $s);
	}
    }

    # save @ISA for further use, re-evaluate @ISA
    @ORIG_ISA = @ISA unless $FirstTime++;
    @ISA      = ($pkg, @pkg, @ORIG_ISA);

    if ($debug) {
	printf STDERR "%-20s %s\n", "IO::Adapter::ISA:", "@ISA";
	print  STDERR "use $pkg\n";
    }
    eval qq{ use $pkg; };
    unless ($@) {
	$pkg->configure($me, $args) if $pkg->can('configure');
    }
    else {
	error_set($me, $@);
    }

    return bless $me, $type;
}


=head2

=item C<open([$flag])>

open IO operation for the map.
C<$flag> is passed to SUPER CLASS open()
when "file:" map is specified.
C<open()> is a dummy function in other maps now.

=cut


# Descriptions: open IO, each request is forwraded to each sub-class.
#    Arguments: OBJ($self) STR($flag)
#               $flag is the same as open()'s flag for file: map but
#               "r" only for other maps.
# Side Effects: none
# Return Value: HANDLE
sub open
{
    my ($self, $flag) = @_;
    my $type = $self->{ _type };

    # default flag is "r" == "read open"
    $flag ||= 'r';

    if ($type eq 'file') {
	$self->SUPER::open( { file => $self->{_file}, flag => $flag } );
    }
    elsif ($type eq 'unix.group' ||
	   $type eq 'array_reference') {
	$self->SUPER::open( { flag => $flag } );
    }
    elsif ($type =~ /^(ldap|mysql|postgresql)$/o) {
	$self->SUPER::open( { flag => $flag } );
    }
    else {
	$self->error_set("Error: type=$self->{_type} is unknown type.");
    }
}


=head2 touch()

create a file if not exists.
This method is avaialble for file: type.
It is dummy for maps other than file: type.

=cut


# Descriptions: create a file if not exists.
#    Arguments: OBJ($self)
# Side Effects: create $map if needed or possible
# Return Value: none
sub touch
{
    my ($self) = @_;
    my $type   = $self->{ _type };

    if ($type eq 'file') {
	$self->SUPER::touch( { file => $self->{_file} } );
    }
}


=head2 methods to retrieve data

get_next_key() is used to get the next primary key incrementally.

Also, another methods, getline() and get_next_value(), can be
considered but these are not userd in fml version 8 now.

=item C<get_next_key()>

return the next primary key.

=head2 add( $address, [$argv] )

add $address to the specified map.

Optionally, you can add KEY=>VALUE structures such as
  $address => STR
or
  $address => [ STR1, STR2, ... ].


=head2 delete( $address )

delete lines which matches $regexp from this map.

=cut


# Descriptions: add $address to the current map.
#    Arguments: OBJ($self) STR($address) VARARGS($argv)
# Side Effects: modify map content, croak() if critical error.
# Return Value: same as add()
sub add
{
    my ($self, $address, $argv) = @_;

    if ($self->{ _hints }->{ read_only }) {
	my $map = $self->{ _map };
	croak("this map $map is read only.");
    }

    if ($self->can('add')) {
	$self->SUPER::add($address, $argv);
    }
    else {
	$self->error_set("Error: add() method is not supported.");
	undef;
    }
}


# Descriptions: delete $address from the current map.
#    Arguments: OBJ($self) STR($regexp)
# Side Effects: moidfy map content, croak() if critical error.
# Return Value: same as delete()
sub delete
{
    my ($self, $regexp) = @_;

    if ($self->{ _hints }->{ read_only }) {
	my $map = $self->{ _map };
	croak("this map $map is read only.");
    }

    if ($self->can('delete')) {
	$self->SUPER::delete($regexp);
    }
    else {
	$self->error_set("Error: delete() method is not supported.");
	undef;
    }
}


=head2 find($regexp [,$args])

search $regexp in C<map> and return the line which matches C<$regexp>.
It searches C<$regexp> in case insenssitive by default.
You can change the search behaviour by C<$args> (HASH REFERENCE).

    $args = {
	want           => 'key', # 'key' or 'key,value'
	case_sensitive => 1, # case senssitive
	all            => 1, # get all entries matching $regexp as ARRAY REF
    };

The result returned by find() is primary key of data or key and value
e.g the whole line in the file format. find() returns the whole one
line by default. If want options is specified in $args, return value
changes. 'want' options is 'key' or 'key,value', 'key,value' by default.

find() returns the result as STRING or ARRAY REFERENCE.
You get only the first entry as string by default.
If you specify C<all>, you get the result(s) as ARRAY REFERENCE.

For example, to search mail addresses in recipient list,

    my $a = $self->find($regexp, { want => 'key', all => 1});
    for my $addr (@$a) {
        do_somethig() if ($addr =~ /$regexp/);
    }

=cut


# Descriptions: search method. 
#               call map dependent routine md_find() if defined in the map.
#    Arguments: OBJ($self) STR($regexp) HASH_REF($args)
# Side Effects: none
# Return Value: STR or ARRAY_REF
sub find
{
    my ($self, $regexp, $args) = @_;
    my $case_sensitive = $args->{ case_sensitive } ? 1 : 0;
    my $show_all       = $args->{ all } ? 1 : 0;
    my $want           = 'key,value';

    # forward the request to SUPER class (md = map dependent)
    if ($self->SUPER::can('md_find')) {
	return $self->md_find($regexp, $args);
    }

    # we may need quote for special address e.g. a+b@domain.
    $regexp = quotemeta($regexp);

    # What we want, key or  key+value ?
    if (defined $args->{ want }) {
	if ($args->{ want } eq 'key' ||
	    $args->{ want } eq 'key,value') {
	    $want = $args->{ want };
	}
	else {
	    warn("invalid option");
	}
    }

    # search regexp by reading the specified map.
    my (@buf) = ();
    my $x     = '';

    $self->open;
    my $fp = $want eq 'key' ? 'get_next_key' : 'getline';
  DATA:
    while (defined ($x = $self->$fp())) {
	if ($show_all) {
	    if ($case_sensitive) {
		push(@buf, $x) if $x =~ /$regexp/;
	    }
	    else {
		push(@buf, $x) if $x =~ /$regexp/i;
	    }
	}
	else {
	    if ($case_sensitive) {
		last DATA if $x =~ /$regexp/;
	    }
	    else {
		last DATA if $x =~ /$regexp/i;
	    }
	}
    }

    $self->close;

    $show_all ? \@buf : $x;
}


=head2 DESTROY

=cut

# Descriptions: destructor.
#               request is forwarded to close() method.
#    Arguments: OBJ($self)
# Side Effects: object is undef'ed.
# Return Value: none
sub DESTROY
{
    my ($self) = @_;
    $self->close;
    undef $self;
}



=head2

=item C<error()>

return the most recent error message if exists.

=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

Ken'ichi Fukamchi

=head1 COPYRIGHT

Copyright (C) 2001,2002,2003,2004 Ken'ichi Fukamchi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

IO::Adapter first appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut

1;
