# The -*- perl -*- script writes the Makefile for perl-ldap

use 5.004;
use ExtUtils::MakeMaker;
use Getopt::Std;
use Config;

#--- Configure ---

if (!getopts("hs") || $opt_h) {
  die <<"EDQ";
Usage: perl $0 [-h] [-s] [ MAKEMAKER_ARGS ]
  -h  Display this message
  -s  Install scripts from bin directory
EDQ
}

#--- Distribution section ---

$DISTNAME     = 'perl-ldap';
$VERSION_FROM = 'lib/Net/LDAP.pm';
$AUTHOR       = 'Graham Barr <gbarr@pobox.com>';

($ABSTRACT = <<"EDQ") =~ s/\n/\\n/g;
perl-ldap is a library of modules implementing an LDAP client. The aim
of the perl-ldap project is to implement a very portable LDAP client in
perl by relying on as little compiled code as possible.
EDQ

#--- Check for required modules ---

my $missing = 0;
$| = 1;

sub check_module {
  my($module,$version) = @_;
  print substr("$module ............................",0,30);
  my $ok = eval {
    my $file = $module;
    $file =~ s#::#/#g;
    require $file . ".pm";
    $module->VERSION($version) if defined $version;
    1;
  };
  $missing++ unless $ok;
  print $ok ? "ok\n" : "** FAILED **\n$@\n";
  $ok;
}

print "\nChecking for installed modules\n\n";

check_module('Convert::BER',1.23) or print <<"EDQ","\n";
Convert::BER version 1.23 or later is essential for perl-ldap
EDQ

check_module('URI',1.02) && check_module('URI::ldap',1.10) or print <<"EDQ","\n";
URI::ldap is needed if you want to parse LDAP URLs
EDQ

check_module('Digest::MD5') or print <<"EDQ","\n";
The Digest::MD5 module is needed if using the CRAM-MD5 SASL authentication
EDQ

print "\n",<<"EDQ","\n" if $missing;
****************************************************************************
You are missing some modules that may be needed for the modules in perl-ldap
to work correctly. Read the above messages and download any required
modules from http://www.perl.com/CPAN
****************************************************************************
EDQ

#--- Write the Makefile ---

my %PL_FILES = map { ($a = $_) =~ s/\.PL// ? ($_,$a) : () } glob('bin/*.PL');

WriteMakefile(
  VERSION_FROM => $VERSION_FROM,
  NAME         => $DISTNAME,
  EXE_FILES    => $opt_s ? [ values %PL_FILES ] : [],
  PL_FILES     => \%PL_FILES,
  AUTHOR       => $AUTHOR,
  ABSTRACT     => $ABSTRACT,
  clean        => {FILES => 'temp'},
);

