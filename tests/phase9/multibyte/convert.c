#define _GNU_SOURCE
#include <errno.h>
#include <locale.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <uchar.h>
#include <wchar.h>

#ifndef OA_PHASE9_HOST
_Static_assert(sizeof(mbstate_t) == 8 && _Alignof(mbstate_t) == 4, "project mbstate_t ABI");
#endif

static int utf8_locale(void)
{
    return setlocale(LC_CTYPE, "C.UTF-8") && MB_CUR_MAX >= 4;
}

static int direct(const char *name)
{
    mbstate_t state = {0};
    wchar_t wc = 99;
    char16_t c16 = 99;
    char32_t c32 = 99;
    char bytes[5] = {'#', '#', '#', '#', '#'};
    errno = EDOM;
    if (strcmp(name, "btowc") == 0) {
#ifndef OA_PHASE9_HOST
        if (btowc(0x80) != WEOF)
            return 51;
#endif
        return btowc('A') == L'A' && btowc(0) == 0 && btowc(EOF) == WEOF &&
               errno == EDOM ? 0 : 51;
    }
    if (strcmp(name, "wctob") == 0)
        return wctob(L'A') == 'A' && wctob(0) == 0 && wctob(WEOF) == EOF &&
               wctob(0x80) == EOF && errno == EDOM ? 0 : 52;
    if (strcmp(name, "mbsinit") == 0)
        return mbsinit(&state) && mbsinit(NULL) && errno == EDOM ? 0 : 53;
    if (strcmp(name, "mbrlen") == 0)
        return mbrlen("A", 1, &state) == 1 && errno == EDOM ? 0 : 54;
    if (strcmp(name, "mbrtowc") == 0)
        return mbrtowc(&wc, "A", 1, &state) == 1 && wc == L'A' && errno == EDOM ? 0 : 55;
    if (strcmp(name, "wcrtomb") == 0)
        return wcrtomb(bytes, L'A', &state) == 1 && bytes[0] == 'A' &&
               bytes[1] == '#' && errno == EDOM ? 0 : 56;
    if (strcmp(name, "mbrtoc16") == 0)
        return mbrtoc16(&c16, "A", 1, &state) == 1 && c16 == 'A' && errno == EDOM ? 0 : 57;
    if (strcmp(name, "c16rtomb") == 0)
        return c16rtomb(bytes, 'A', &state) == 1 && bytes[0] == 'A' &&
               bytes[1] == '#' && errno == EDOM ? 0 : 58;
    if (strcmp(name, "mbrtoc32") == 0)
        return mbrtoc32(&c32, "A", 1, &state) == 1 && c32 == 'A' && errno == EDOM ? 0 : 59;
    if (strcmp(name, "c32rtomb") == 0)
        return c32rtomb(bytes, 'A', &state) == 1 && bytes[0] == 'A' &&
               bytes[1] == '#' && errno == EDOM ? 0 : 60;
    return 91;
}

static size_t reference_utf8(char *bytes, uint32_t value)
{
    if (value < 0x80) {
        bytes[0] = (char)value;
        return 1;
    }
    static const unsigned char lead[] = {0, 0, 0xc0, 0xe0, 0xf0};
    size_t width = value < 0x800 ? 2 : value < 0x10000 ? 3 : 4;
    for (size_t i = width - 1; i; --i) {
        bytes[i] = (char)(0x80 | (value & 0x3f));
        value >>= 6;
    }
    bytes[0] = (char)(lead[width] | value);
    return width;
}

static int valid_scalars(unsigned family)
{
    if (!utf8_locale())
        return 61;
    mbstate_t decode = {0}, encode = {0};
    unsigned checked = 0;
    errno = EDOM;
    for (uint32_t scalar = 0; scalar <= 0x10ffff; ++scalar) {
        if (scalar >= 0xd800 && scalar <= 0xdfff)
            continue;
        char wanted[4], bytes[5] = {'#', '#', '#', '#', '#'};
        size_t width = reference_utf8(wanted, scalar);
        size_t consumed = scalar ? width : 0;
        size_t produced;
        if (family == 32) {
            char32_t actual = 0xffffffffu;
            if (mbrtoc32(&actual, wanted, width, &decode) != consumed || actual != scalar)
                return 62;
            produced = c32rtomb(bytes, scalar, &encode);
        } else if (family == 16) {
            char16_t high = (char16_t)scalar, low = 0, actual = 0xdead;
            if (scalar >= 0x10000) {
                high = (char16_t)(0xd800 + ((scalar - 0x10000) >> 10));
                low = (char16_t)(0xdc00 + (scalar & 0x3ff));
            }
            if (mbrtoc16(&actual, wanted, width, &decode) != consumed || actual != high)
                return 63;
            if (low) {
                if (mbsinit(&decode) || mbrtoc16(&actual, "X", 1, &decode) != (size_t)-3 || actual != low ||
                    c16rtomb(bytes, high, &encode) != 0 || bytes[0] != '#' || mbsinit(&encode))
                    return 64;
                produced = c16rtomb(bytes, low, &encode);
            } else {
                produced = c16rtomb(bytes, high, &encode);
            }
        } else {
            wchar_t actual = -1;
            if (mbrtowc(&actual, wanted, width, &decode) != consumed || actual != (wchar_t)scalar)
                return 65;
            produced = wcrtomb(bytes, (wchar_t)scalar, &encode);
        }
        if (produced != width || memcmp(bytes, wanted, width) || bytes[width] != '#' ||
            !mbsinit(&decode) || !mbsinit(&encode) || errno != EDOM)
            return 66;
        ++checked;
    }
    return checked == 1112064 ? 0 : 67;
}

static int split(void)
{
    if (!utf8_locale())
        return 70;
    mbstate_t state = {0};
    wchar_t value = 0x5555;
    errno = EDOM;
    if (mbrtowc(&value, "\xe2", 0, &state) != (size_t)-2 || !mbsinit(&state) || value != 0x5555)
        return 71;
    if (mbrtowc(&value, "\xe2", 1, &state) != (size_t)-2 || mbsinit(&state) || value != 0x5555)
        return 72;
    mbstate_t copy = state;
    if (mbrtowc(&value, "\x82\xac", 2, &state) != 2 || value != 0x20ac || !mbsinit(&state))
        return 73;
    if (mbrtowc(&value, "\x82", 1, &copy) != (size_t)-2 || value != 0x20ac ||
        mbrtowc(&value, "\xad", 1, &copy) != 1 || value != 0x20ad || !mbsinit(&copy))
        return 74;
    if (mbrtowc(&value, NULL, 0, &state) || value != 0x20ad || errno != EDOM)
        return 75;
    if (mbrtowc(&value, "", 1, &state) || value || wcrtomb(NULL, 0x20ac, &state) != 1 ||
        mbrlen("", 1, &state) || !mbsinit(&state) || errno != EDOM)
        return 76;
    return 0;
}

static int defaults(void)
{
    if (!utf8_locale())
        return 80;
    wchar_t wc = 0;
    char32_t c32 = 0;
    char16_t c16 = 0;
    char bytes[5] = {'#', '#', '#', '#', '#'};
    errno = EDOM;
    if (mbrlen("\xe2", 1, NULL) != (size_t)-2 ||
        mbrtowc(&wc, "W", 1, NULL) != 1 || wc != L'W' ||
        mbrtoc32(&c32, "Q", 1, NULL) != 1 || c32 != 'Q' ||
        mbrlen("\x82\xac", 2, NULL) != 2)
        return 81;
    if (mbrtoc16(&c16, "\xf0\x9f\x99\x82", 4, NULL) != 4 || c16 != 0xd83d ||
        mbrtowc(&wc, "Z", 1, NULL) != 1 || wc != L'Z' ||
        mbrtoc16(&c16, "A", 0, NULL) != (size_t)-3 || c16 != 0xde42 ||
        mbrtoc16(&c16, "A", 1, NULL) != 1 || c16 != 'A')
        return 82;
    if (c16rtomb(bytes, 0xd83d, NULL) || bytes[0] != '#' ||
        wcrtomb(bytes, L'W', NULL) != 1 || bytes[0] != 'W' ||
        c32rtomb(bytes, 'Q', NULL) != 1 || bytes[0] != 'Q' ||
        c16rtomb(bytes, 0xde42, NULL) != 4 || memcmp(bytes, "\xf0\x9f\x99\x82", 4) ||
        bytes[4] != '#' || errno != EDOM)
        return 83;
    return 0;
}

static int invalid(void)
{
    mbstate_t state = {0};
    char32_t value = 0x1111;
    for (unsigned byte = 0x80; byte <= 0xff; ++byte) {
        char input = (char)byte;
        errno = EDOM;
        if (mbrtoc32(&value, &input, 1, &state) != (size_t)-1 ||
            errno != EILSEQ || value != 0x1111 || !mbsinit(&state))
            return 84;
    }
    char output[8] = {'#', '#', '#', '#', '#', '#', '#', '#'};
    if (c16rtomb(output, 0xd800, &state) != (size_t)-1 || errno != EILSEQ ||
        output[0] != '#' || !mbsinit(&state) || !utf8_locale())
        return 85;
    static const struct { const char *bytes; size_t size; } malformed[] = {
        {"\x80", 1}, {"\xc0\x80", 2}, {"\xc1\xbf", 2}, {"\xe0\x9f\xbf", 3},
        {"\xed\xa0\x80", 3}, {"\xf0\x8f\xbf\xbf", 4}, {"\xf4\x90\x80\x80", 4},
        {"\xf5", 1}, {"\xff", 1}, {"\xe2" "A", 2}, {"\xe2\x82", 3},
    };
    for (size_t i = 0; i < sizeof malformed / sizeof malformed[0]; ++i) {
        errno = EDOM;
        if (mbrtoc32(&value, malformed[i].bytes, malformed[i].size, &state) != (size_t)-1 ||
            errno != EILSEQ || value != 0x1111 || !mbsinit(&state))
            return 86;
    }
    errno = EDOM;
    if (mbrtoc32(&value, "\xf4", 1, &state) != (size_t)-2 || errno != EDOM ||
        mbrtoc32(&value, "\x90", 1, &state) != (size_t)-1 || errno != EILSEQ ||
        !mbsinit(&state) || value != 0x1111)
        return 87;
    errno = EDOM;
    if (c32rtomb(output, 0x110000, &state) != (size_t)-1 || errno != EILSEQ ||
        wcrtomb(output, -1, &state) != (size_t)-1 || errno != EILSEQ ||
        c16rtomb(output, 0xdc00, &state) != (size_t)-1 || errno != EILSEQ ||
        c16rtomb(output, 0xd83d, &state) != 0 ||
        c16rtomb(NULL, 0xde42, &state) != (size_t)-1 || errno != EILSEQ ||
        !mbsinit(&state) || output[0] != '#')
        return 88;
    errno = EDOM;
    return mbrtoc32(&value, "A", 1, &state) == 1 && value == 'A' && errno == EDOM ? 0 : 89;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    const char *name = argv[1];
    if (strcmp(name, "scalar32") == 0)
        return valid_scalars(32);
    if (strcmp(name, "scalar16") == 0)
        return valid_scalars(16);
    if (strcmp(name, "scalar-wide") == 0)
        return valid_scalars(0);
    if (strcmp(name, "split") == 0)
        return split();
    if (strcmp(name, "defaults") == 0)
        return defaults();
    if (strcmp(name, "invalid") == 0)
        return invalid();
    return direct(name);
}
