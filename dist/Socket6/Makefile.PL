# Copyright (C) 2000 Hajimu UMEMOTO <ume@mahoroba.org>.
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of the project nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

# $Id: Makefile.PL,v 1.3 2000/04/15 07:26:44 ume Exp $

use ExtUtils::MakeMaker;

my $path_perl = ($^X =~ m!^/!o) ? $^X : `which $^X`;
my $cmd = './configure';
$cmd .= " --with-perl=$path_perl" if ($path_perl);
system($cmd);
require 'config.pl';

WriteMakefile(
    NAME	 => 'Socket6',
    VERSION_FROM => 'Socket6.pm',
    MAN3PODS 	 => {},			# Pods will be built by installman.
    XSPROTOARG	 => '-noprototypes',	# XXX remove later?
    PM		 => {'Socket6.pm' => '$(INST_LIBDIR)/Socket6.pm'},
    CC		 => "${cc}",
    LIBS	 => ["${libs}"],
    realclean	 => {FILES => 'config.cache config.h config.log config.pl config.status gailookup.pl'},
);
