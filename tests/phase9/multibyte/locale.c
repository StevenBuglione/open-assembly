#define _GNU_SOURCE
#include <errno.h>
#include <limits.h>
#include <locale.h>
#include <stdlib.h>
#include <string.h>

static int equal(const char *actual, const char *expected)
{
    return actual && strcmp(actual, expected) == 0;
}

static int locale_record(void)
{
    errno = EDOM;
    const struct lconv *record = localeconv();
    if (!record || !equal(record->decimal_point, ".") || errno != EDOM)
        return 30;
    const char *const empty_fields[] = {
        record->thousands_sep, record->grouping, record->int_curr_symbol,
        record->currency_symbol, record->mon_decimal_point, record->mon_thousands_sep,
        record->mon_grouping, record->positive_sign, record->negative_sign,
    };
    for (size_t i = 0; i < sizeof empty_fields / sizeof empty_fields[0]; ++i) {
        if (!equal(empty_fields[i], ""))
            return 31;
    }
    const unsigned char flags[] = {
        record->int_frac_digits, record->frac_digits, record->p_cs_precedes, record->p_sep_by_space,
        record->n_cs_precedes, record->n_sep_by_space, record->p_sign_posn, record->n_sign_posn,
        record->int_p_cs_precedes, record->int_p_sep_by_space, record->int_n_cs_precedes,
        record->int_n_sep_by_space, record->int_p_sign_posn, record->int_n_sign_posn,
    };
    for (size_t i = 0; i < sizeof flags / sizeof flags[0]; ++i) {
        if (flags[i] != CHAR_MAX)
            return 32;
    }
    return 0;
}

static int locale_names(void)
{
    errno = EDOM;
    if (!equal(setlocale(LC_ALL, NULL), "C") || MB_CUR_MAX != 1 || errno != EDOM)
        return 10;
    if (!equal(setlocale(LC_ALL, "POSIX"), "C") || MB_CUR_MAX != 1 || errno != EDOM)
        return 11;
    if (!equal(setlocale(LC_CTYPE, "C.utf8"), "C.UTF-8") || MB_CUR_MAX != 4 || errno != EDOM)
        return 12;
    if (!equal(setlocale(LC_NUMERIC, NULL), "C") || !equal(setlocale(LC_TIME, NULL), "C"))
        return 13;
    if (setlocale(LC_ALL, "invalid-locale") || setlocale(-1, "C") || errno != EDOM ||
        !equal(setlocale(LC_CTYPE, NULL), "C.UTF-8"))
        return 14;
    if (setlocale(LC_ALL, "LC_CTYPE=C;LC_NUMERIC=invalid-locale") ||
        !equal(setlocale(LC_CTYPE, NULL), "C.UTF-8") || errno != EDOM)
        return 15;
    return locale_record();
}

static int environment(void)
{
    if (setenv("LC_ALL", "", 1) || setenv("LANG", "C.utf8", 1) ||
        setenv("LC_CTYPE", "POSIX", 1) || setenv("LC_NUMERIC", "C.UTF-8", 1))
        return 20;
    errno = EDOM;
    const char *mixed = setlocale(LC_ALL, "");
    char snapshot[256];
    if (!mixed || strlen(mixed) >= sizeof snapshot || errno != EDOM ||
        !strstr(mixed, "LC_CTYPE=C;"))
        return 21;
    strcpy(snapshot, mixed);
    if (!equal(setlocale(LC_CTYPE, NULL), "C") || !equal(setlocale(LC_NUMERIC, NULL), "C.UTF-8") ||
        !equal(setlocale(LC_MESSAGES, NULL), "C.UTF-8") || MB_CUR_MAX != 1)
        return 22;
    if (setenv("LC_ALL", "POSIX", 1) || !equal(setlocale(LC_ALL, ""), "C") || MB_CUR_MAX != 1)
        return 23;
    if (!equal(setlocale(LC_ALL, snapshot), snapshot) ||
        !equal(setlocale(LC_NUMERIC, NULL), "C.UTF-8"))
        return 24;
    if (unsetenv("LC_ALL") || setenv("LC_CTYPE", "C.UTF-8", 1) ||
        setenv("LC_NUMERIC", "no-such-locale", 1))
        return 25;
    errno = EDOM;
    if (setlocale(LC_ALL, "") || !equal(setlocale(LC_ALL, NULL), snapshot) || errno != EDOM)
        return 26;
    if (unsetenv("LC_NUMERIC") || unsetenv("LC_CTYPE") || unsetenv("LANG") ||
        !equal(setlocale(LC_ALL, ""), "C") || MB_CUR_MAX != 1)
        return 27;
    return 0;
}

static int record_both_locales(void)
{
    int status = locale_record();
    if (status)
        return status;
    if (!setlocale(LC_ALL, "C.UTF-8"))
        return 33;
    return locale_record();
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (strcmp(argv[1], "names") == 0)
        return locale_names();
    if (strcmp(argv[1], "environment") == 0)
        return environment();
    if (strcmp(argv[1], "record") == 0)
        return record_both_locales();
    return 91;
}
