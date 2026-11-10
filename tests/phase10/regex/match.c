#define _XOPEN_SOURCE 700
#include <locale.h>
#include <regex.h>
#include <stddef.h>
#include <string.h>

static int capture(regmatch_t value, regoff_t start, regoff_t end)
{
    return value.rm_so == start && value.rm_eo == end;
}

static int compile(void)
{
    regex_t expression = {0};
    if (regcomp(&expression, "(ab|a)(c)?", REG_EXTENDED) || expression.re_nsub != 2)
        return 11;
    regfree(&expression);
    if (regcomp(&expression, "a{3,2}", REG_EXTENDED) != REG_BADBR)
        return 12;
    if (regcomp(&expression, "(unclosed", REG_EXTENDED) != REG_EPAREN)
        return 13;
    return 0;
}

static int captures(void)
{
    regex_t expression = {0};
    if (regcomp(&expression, "(ab|a)(c)?", REG_EXTENDED))
        return 90;
    regmatch_t matches[5];
    for (size_t i = 0; i < 5; ++i)
        matches[i] = (regmatch_t){41, 49};
    int result = regexec(&expression, "XabYac", 4, matches, 0);
    regfree(&expression);
    if (result || !capture(matches[0], 1, 3) || !capture(matches[1], 1, 3) ||
        !capture(matches[2], -1, -1) || !capture(matches[3], -1, -1) ||
        !capture(matches[4], 41, 49))
        return 21;

    if (regcomp(&expression, "^\\(ab\\)\\1$", 0))
        return 90;
    int ok = regexec(&expression, "abab", 2, matches, 0) == 0 &&
             capture(matches[0], 0, 4) && capture(matches[1], 0, 2) &&
             regexec(&expression, "abac", 0, NULL, 0) == REG_NOMATCH;
    regfree(&expression);
    return ok ? 0 : 22;
}

static int anchors(void)
{
    regex_t expression = {0};
    regmatch_t match;
    if (regcomp(&expression, "^a.b$", REG_EXTENDED) ||
        regexec(&expression, "a\nb", 1, &match, 0) || !capture(match, 0, 3))
        return 23;
    regfree(&expression);
    if (regcomp(&expression, "^a.b$", REG_EXTENDED | REG_NEWLINE) ||
        regexec(&expression, "a\nb", 1, &match, 0) != REG_NOMATCH)
        return 24;
    regfree(&expression);
    if (regcomp(&expression, "^[^z]$", REG_EXTENDED | REG_NEWLINE) ||
        regexec(&expression, "x\n\na\ny", 1, &match, REG_NOTBOL | REG_NOTEOL) ||
        !capture(match, 3, 4))
        return 25;
    regfree(&expression);
    if (regcomp(&expression, "(a?)*", REG_EXTENDED) ||
        regexec(&expression, "", 1, &match, 0) || !capture(match, 0, 0))
        return 26;
    regfree(&expression);
    return 0;
}

static int nosub(void)
{
    regex_t expression = {0};
    if (regcomp(&expression, "(abc)", REG_EXTENDED | REG_NOSUB))
        return 90;
    regmatch_t matches[] = {{55, 66}, {77, 88}};
    int ok = regexec(&expression, "zabcz", 2, matches, 0) == 0 &&
             capture(matches[0], 55, 66) && capture(matches[1], 77, 88) &&
             regexec(&expression, "zabcz", 0, NULL, 0) == 0;
    regfree(&expression);
    return ok ? 0 : 27;
}

static int diagnostic(void)
{
    const int codes[] = {REG_BADPAT, REG_BADBR, REG_EPAREN, REG_NOMATCH, REG_ESPACE};
    for (size_t i = 0; i < sizeof codes / sizeof codes[0]; ++i) {
        char full[256], short_buffer[] = {'#', '#', '#', '#', '#', '#'};
        size_t count = regerror(codes[i], NULL, NULL, 0);
        if (count <= 1 || count > sizeof full)
            return 31;
        if (regerror(codes[i], NULL, full, sizeof full) != count || strlen(full) + 1 != count)
            return 32;
        if (regerror(codes[i], NULL, short_buffer + 1, 4) != count ||
            memcmp(short_buffer + 1, full, count - 1 < 3 ? count - 1 : 3) ||
            short_buffer[count < 4 ? count : 4] || short_buffer[0] != '#' || short_buffer[5] != '#')
            return 33;
    }
    return 0;
}

#ifndef OA_PHASE10_HOST
static int release(void)
{
    regex_t expression = {0};
    if (regcomp(&expression, "(abc)", REG_EXTENDED) || expression.re_nsub != 1)
        return 90;
    regfree(&expression);
    return expression.re_nsub ? 41 : 0;
}

static int policy(void)
{
    regex_t expression = {0};
    regmatch_t matches[3];
    const struct { const char *pattern, *subject; int flags; regoff_t start, end; } locale[] = {
        {"[[:alpha:]]+", "!\xc3\xa9\xce\xa9?", 0, 1, 5},
        {"^.$", "\xc3\xa9", 0, 0, 2},
        {"^\xc3\x89$", "\xc3\xa9", REG_ICASE, 0, 2},
        {"^[\xc3\x89]$", "\xc3\xa9", REG_ICASE, 0, 2},
    };
    for (size_t i = 0; i < sizeof locale / sizeof locale[0]; ++i) {
        if (!setlocale(LC_CTYPE, "C.UTF-8") ||
            regcomp(&expression, locale[i].pattern, REG_EXTENDED | locale[i].flags))
            return 90;
        if (!setlocale(LC_CTYPE, "C") || regexec(&expression, locale[i].subject, 1, matches, 0) ||
            !capture(matches[0], locale[i].start, locale[i].end))
            return i ? 48 + (int)i : 42;
        regfree(&expression);
    }
    if (regcomp(&expression, "[[:alpha:]]+", REG_EXTENDED) ||
        !setlocale(LC_CTYPE, "C.UTF-8") ||
        regexec(&expression, "!\xc3\xa9\xce\xa9?", 0, NULL, 0) != REG_NOMATCH)
        return 52;
    regfree(&expression);
    if (!setlocale(LC_CTYPE, "C.UTF-8") || regcomp(&expression, "\xff", REG_EXTENDED) != REG_BADPAT)
        return 43;
    if (regcomp(&expression, "a\\1", REG_EXTENDED) || regexec(&expression, "a1", 1, matches, 0) ||
        !capture(matches[0], 0, 2))
        return 44;
    regfree(&expression);
    if (regcomp(&expression, "^(a|aa)(a?)$", REG_EXTENDED) ||
        regexec(&expression, "aa", 3, matches, 0) || !capture(matches[0], 0, 2) ||
        !capture(matches[1], 0, 2) || !capture(matches[2], 2, 2))
        return 45;
    regfree(&expression);
    if (regcomp(&expression, "^.*(ab|\xf0\x90\x80\x80).*$", REG_EXTENDED) ||
        regexec(&expression, "ab\xf0\x90\x80\x80", 2, matches, 0) ||
        !capture(matches[0], 0, 6) || !capture(matches[1], 0, 2))
        return 48;
    regfree(&expression);
    char many[256];
    memset(many, 'a', sizeof many - 1);
    many[sizeof many - 1] = 0;
    if (regcomp(&expression, "^a{255}$", REG_EXTENDED) ||
        regexec(&expression, many, 1, matches, 0) || !capture(matches[0], 0, 255) ||
        regexec(&expression, many + 1, 0, NULL, 0) != REG_NOMATCH)
        return 46;
    regfree(&expression);
    if (regcomp(&expression, "a{256}", REG_EXTENDED) != REG_BADBR)
        return 47;
    return 0;
}
#endif

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "compile"))
        return compile();
    if (!strcmp(argv[1], "captures"))
        return captures();
    if (!strcmp(argv[1], "anchors"))
        return anchors();
    if (!strcmp(argv[1], "nosub"))
        return nosub();
    if (!strcmp(argv[1], "diagnostic"))
        return diagnostic();
#ifndef OA_PHASE10_HOST
    if (!strcmp(argv[1], "release"))
        return release();
    if (!strcmp(argv[1], "policy"))
        return policy();
#endif
    return 91;
}
