#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

static int
not_here(s)
char *s;
{
    croak("%s not implemented on this architecture", s);
    return -1;
}

#define PERL_XS 1
#include "unicode.c"

MODULE = Jcode::Unicode	PACKAGE = Jcode::Unicode

PROTOTYPES: ENABLE

char *
euc_ucs2(src, ...)
        SV *            src
    PROTOTYPE: $;$
    CODE:
        STRLEN srclen;
        STRLEN dstlen;
        char *s = SvROK(src) ? SvPV(SvRV(src), srclen) :SvPV(src, srclen);
	int pedantic = 0;
        if (items > 1) { pedantic = SvIV(ST(1)); };
        dstlen = srclen * 3 + 10; /* large enough? */
	ST(0) = sv_2mortal(newSV(dstlen));
	dstlen = _euc_ucs2(SvPVX(ST(0)), s, pedantic);
        SvCUR_set(ST(0), dstlen);
        SvPOK_only(ST(0));
	if (SvROK(src)) { sv_setsv(SvRV(src), ST(0)); }

char *
ucs2_euc(src, ...)
        SV *            src
    PROTOTYPE: $;$
    CODE:
        STRLEN srclen;
        STRLEN dstlen;
        char *s = SvROK(src) ? SvPV(SvRV(src), srclen) :SvPV(src, srclen);
	int pedantic = 0;
        if (items > 1) { pedantic = SvIV(ST(1)); };
        dstlen = srclen * 3 + 10; /* large enough? */
        ST(0) = sv_2mortal(newSV(dstlen));
        dstlen = _ucs2_euc(SvPVX(ST(0)), s, srclen, pedantic);
        SvCUR_set(ST(0), dstlen);
        SvPOK_only(ST(0));
	if (SvROK(src)) { sv_setsv(SvRV(src), ST(0)); }

char *
utf8_ucs2(src, ...)
        SV *            src
    PROTOTYPE: $
    CODE:
        STRLEN srclen;
        STRLEN dstlen;
        char *s = SvROK(src) ? SvPV(SvRV(src), srclen) :SvPV(src, srclen);
        dstlen = srclen * 3 + 10; /* large enough? */
        ST(0) = sv_2mortal(newSV(dstlen));
        dstlen = _utf8_ucs2(SvPVX(ST(0)), s);
        SvCUR_set(ST(0), dstlen);
        SvPOK_only(ST(0));
	if (SvROK(src)) { sv_setsv(SvRV(src), ST(0)); }

char *
ucs2_utf8(src, ...)
        SV *            src
    PROTOTYPE: $
    CODE:
        STRLEN srclen;
        STRLEN dstlen;
        char *s = SvROK(src) ? SvPV(SvRV(src), srclen) :SvPV(src, srclen);
        dstlen = srclen * 3 + 10; /* large enough? */
        ST(0) = sv_2mortal(newSV(dstlen));
        dstlen = _ucs2_utf8(SvPVX(ST(0)), s, srclen);
        SvCUR_set(ST(0), dstlen);
        SvPOK_only(ST(0));
	if (SvROK(src)) { sv_setsv(SvRV(src), ST(0)); }




