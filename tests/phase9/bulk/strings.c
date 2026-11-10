#define _GNU_SOURCE
#include <errno.h>
#include <locale.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

static const char encoded[] = "A\xe2\x82\xac\xf0\x9f\x99\x82Z";
static const wchar_t decoded[] = {L'A', 0x20ac, 0x1f642, L'Z', 0};

static int direct(const char *name)
{
    const char *narrow = encoded;
    const wchar_t *wide = decoded;
    char bytes[5] = {'#', '#', '#', '#', '#'};
    wchar_t output[2] = {0x1234, 0x5678};
    mbstate_t state = {0};
    errno = EDOM;
    if (strcmp(name, "mblen") == 0)
        return mblen(encoded + 1, 3) == 3 && errno == EDOM ? 0 : 11;
    if (strcmp(name, "mbtowc") == 0)
        return mbtowc(output, encoded + 1, 3) == 3 && output[0] == 0x20ac && errno == EDOM ? 0 : 12;
    if (strcmp(name, "wctomb") == 0)
        return wctomb(bytes, 0x20ac) == 3 && memcmp(bytes, encoded + 1, 3) == 0 &&
               bytes[3] == '#' && errno == EDOM ? 0 : 13;
    if (strcmp(name, "mbstowcs") == 0)
        return mbstowcs(output, encoded, 1) == 1 && output[0] == L'A' &&
               output[1] == 0x5678 && errno == EDOM ? 0 : 14;
    if (strcmp(name, "wcstombs") == 0)
        return wcstombs(bytes, decoded, 2) == 1 && bytes[0] == 'A' &&
               bytes[1] == '#' && errno == EDOM ? 0 : 15;
    if (strcmp(name, "mbsrtowcs") == 0)
        return mbsrtowcs(output, &narrow, 1, &state) == 1 && output[0] == L'A' &&
               narrow == encoded + 1 && errno == EDOM ? 0 : 16;
    if (strcmp(name, "wcsrtombs") == 0)
        return wcsrtombs(bytes, &wide, 2, &state) == 1 && bytes[0] == 'A' &&
               bytes[1] == '#' && wide == decoded + 1 && errno == EDOM ? 0 : 17;
    return 91;
}

static int from_bytes(void)
{
    const char *input = encoded;
    wchar_t output[6] = {9, 9, 9, 9, 9, 9};
    mbstate_t state = {0};
    errno = EDOM;
    if (mbsrtowcs(output, &input, 0, &state) || input != encoded || output[0] != 9 ||
        mbsrtowcs(NULL, &input, 0, &state) != 4 || input != encoded || !mbsinit(&state))
        return 21;
    if (mbsrtowcs(output, &input, 2, &state) != 2 || input != encoded + 4 ||
        output[0] != L'A' || output[1] != 0x20ac || output[2] != 9)
        return 22;
    if (mbsrtowcs(output + 2, &input, 2, &state) != 2 || input != encoded + 9 ||
        output[2] != 0x1f642 || output[3] != L'Z' || output[4] != 9)
        return 23;
    if (mbsrtowcs(output + 4, &input, 1, &state) || input != NULL || output[4] != 0 ||
        output[5] != 9 || errno != EDOM || !mbsinit(&state))
        return 24;
    return 0;
}

static int to_bytes(void)
{
    const wchar_t *input = decoded;
    char output[12];
    memset(output, '#', sizeof output);
    mbstate_t state = {0};
    errno = EDOM;
    if (wcsrtombs(output, &input, 0, &state) || input != decoded || output[0] != '#' ||
        wcsrtombs(NULL, &input, 0, &state) != 9 || input != decoded || !mbsinit(&state))
        return 31;
    if (wcsrtombs(output, &input, 2, &state) != 1 || input != decoded + 1 ||
        output[0] != 'A' || output[1] != '#')
        return 32;
    if (wcsrtombs(output + 1, &input, 3, &state) != 3 || input != decoded + 2 ||
        memcmp(output, encoded, 4) || output[4] != '#')
        return 33;
    if (wcsrtombs(output + 4, &input, 5, &state) != 5 || input != decoded + 4 ||
        memcmp(output, encoded, 9) || output[9] != '#')
        return 34;
    if (wcsrtombs(output + 9, &input, 1, &state) || input != NULL || output[9] ||
        output[10] != '#' || errno != EDOM || !mbsinit(&state))
        return 35;
    return 0;
}

static int oneshot(void)
{
    wchar_t wide[6] = {9, 9, 9, 9, 9, 9};
    char bytes[12];
    memset(bytes, '#', sizeof bytes);
    errno = EDOM;
    if (mbstowcs(NULL, encoded, 0) != 4 || wcstombs(NULL, decoded, 0) != 9)
        return 41;
    if (mbstowcs(wide, encoded, 4) != 4 || memcmp(wide, decoded, 4 * sizeof(wchar_t)) || wide[4] != 9)
        return 42;
    if (mbstowcs(wide, encoded, 5) != 4 || wide[4] || wide[5] != 9)
        return 43;
    if (wcstombs(bytes, decoded, 6) != 4 || memcmp(bytes, encoded, 4) || bytes[4] != '#')
        return 44;
    if (wcstombs(bytes, decoded, 10) != 9 || memcmp(bytes, encoded, 10) || bytes[10] != '#' || errno != EDOM)
        return 45;
    return 0;
}

static int legacy(void)
{
    wchar_t output = 9;
    char bytes[5] = {'#', '#', '#', '#', '#'};
    errno = EDOM;
    if (mblen(NULL, 0) || mbtowc(&output, NULL, 0) || output != 9 || wctomb(NULL, 0x20ac))
        return 51;
    if (mblen(encoded + 4, 4) != 4 || mbtowc(&output, encoded + 4, 4) != 4 || output != 0x1f642 ||
        wctomb(bytes, 0x1f642) != 4 || memcmp(bytes, encoded + 4, 4) || bytes[4] != '#')
        return 52;
    if (mblen("", 1) || mbtowc(&output, "", 1) || output || wctomb(bytes, 0) != 1 ||
        bytes[0] || errno != EDOM)
        return 53;
    return 0;
}

static int count_copy(void)
{
    mbstate_t state = {0};
    errno = EDOM;
    if (mbrtowc(NULL, "\xe2", 1, &state) != (size_t)-2 || mbsinit(&state))
        return 61;
    mbstate_t original = state;
    static const char valid[] = "\x82\xacZ", invalid[] = "X";
    const char *input = valid;
    if (mbsrtowcs(NULL, &input, 0, &state) != 2 || input != valid ||
        memcmp(&state, &original, sizeof state) || errno != EDOM)
        return 62;
    input = invalid;
    if (mbsrtowcs(NULL, &input, 40, &state) != (size_t)-1 || input != invalid ||
        memcmp(&state, &original, sizeof state) || errno != EILSEQ)
        return 63;
    input = valid;
    wchar_t result[3] = {9, 9, 9};
    errno = EDOM;
    if (mbsrtowcs(result, &input, 3, &state) != 2 || input || result[0] != 0x20ac ||
        result[1] != L'Z' || result[2] || !mbsinit(&state) || errno != EDOM)
        return 64;
    return 0;
}

static int errors(void)
{
    static const char bad_bytes[] = "A\xe0\x80\x80";
    static const wchar_t bad_wide[] = {L'A', 0xd800, L'Z', 0};
    const char *narrow = bad_bytes;
    const wchar_t *wide = bad_wide;
    wchar_t output[4] = {9, 9, 9, 9};
    char bytes[4] = {'#', '#', '#', '#'};
    mbstate_t state = {0}, original = state;
    errno = EDOM;
    if (mbsrtowcs(output, &narrow, 4, &state) != (size_t)-1 || narrow != bad_bytes + 1 ||
        output[0] != L'A' || output[1] != 9 || errno != EILSEQ || !mbsinit(&state))
        return 71;
    errno = EDOM;
    if (wcsrtombs(NULL, &wide, 0, &state) != (size_t)-1 || wide != bad_wide ||
        memcmp(&state, &original, sizeof state) || errno != EILSEQ)
        return 72;
    errno = EDOM;
    if (wcsrtombs(bytes, &wide, 4, &state) != (size_t)-1 || wide != bad_wide + 1 ||
        bytes[0] != 'A' || bytes[1] != '#' || errno != EILSEQ || !mbsinit(&state))
        return 73;
    errno = EDOM;
    output[0] = 9;
    bytes[0] = '#';
    if (mblen("\xe2", 1) != -1 || errno != EILSEQ || mbtowc(output, "\xe2\x82", 2) != -1 ||
        output[0] != 9 || errno != EILSEQ || wctomb(bytes, 0xd800) != -1 ||
        bytes[0] != '#' || errno != EILSEQ)
        return 74;
    errno = EDOM;
    if (mbtowc(output, "Q", 1) != 1 || output[0] != L'Q' || mblen("Q", 1) != 1 ||
        wctomb(bytes, L'Q') != 1 || bytes[0] != 'Q' || errno != EDOM)
        return 75;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!setlocale(LC_CTYPE, "C.UTF-8"))
        return 92;
    const char *name = argv[1];
    if (strcmp(name, "from-bytes") == 0)
        return from_bytes();
    if (strcmp(name, "to-bytes") == 0)
        return to_bytes();
    if (strcmp(name, "oneshot") == 0)
        return oneshot();
    if (strcmp(name, "legacy") == 0)
        return legacy();
    if (strcmp(name, "count-copy") == 0)
        return count_copy();
    if (strcmp(name, "errors") == 0)
        return errors();
    return direct(name);
}
