#define _GNU_SOURCE
#include <errno.h>
#include <limits.h>
#include <string.h>
#include <time.h>

static const struct tm sample = {
    .tm_sec = 3, .tm_min = 2, .tm_hour = 1, .tm_mday = 9, .tm_mon = 1,
    .tm_year = 120, .tm_wday = 0, .tm_yday = 39, .tm_isdst = -1,
};

static int bytes_equal(const char *actual, const char *wanted, size_t count)
{
    for (size_t i = 0; i < count; ++i) {
        if (actual[i] != wanted[i])
            return 0;
    }
    return 1;
}

static int matches(const char *format, const char *wanted, const struct tm *date)
{
    char output[128];
    size_t count = 0;
    while (wanted[count])
        ++count;
    for (size_t i = 0; i < sizeof output; ++i)
        output[i] = '#';
    errno = EDOM;
    size_t got = strftime(output, sizeof output, format, date);
    return got == count && output[count + 1] == '#' &&
           bytes_equal(output, wanted, count + 1) && errno == EDOM;
}

static int directives(void)
{
    static const struct { const char *format, *text; } cases[] = {
        {"%a|%A|%b|%B|%h", "Sun|Sunday|Feb|February|Feb"},
        {"%c|%x|%X", "Sun Feb  9 01:02:03 2020|02/09/20|01:02:03"},
        {"%C|%d|%D|%e|%F", "20|09|02/09/20| 9|2020-02-09"},
        {"%g|%G|%V|%u", "20|2020|06|7"},
        {"%H|%I|%j|%m|%M|%S", "01|01|040|02|02|03"},
        {"%p|%r|%R|%T", "AM|01:02:03 AM|01:02|01:02:03"},
        {"%U|%W|%w|%y|%Y", "06|05|0|20|2020"},
        {"before%n%t%%after", "before\n\t%after"},
        {"%Ec|%EC|%Ex|%EX|%Ey|%EY", "Sun Feb  9 01:02:03 2020|20|02/09/20|01:02:03|20|2020"},
        {"%Od|%Oe|%OH|%OI|%Om|%OM|%OS|%Ou|%OU|%OV|%Ow|%OW|%Oy",
         "09| 9|01|01|02|02|03|7|06|06|0|05|20"},
    };
    for (size_t i = 0; i < sizeof cases / sizeof cases[0]; ++i) {
        if (!matches(cases[i].format, cases[i].text, &sample))
            return 11 + (int)i;
    }
    struct tm time = sample;
    time.tm_hour = 0;
    time.tm_sec = 60;
    if (!matches("%H|%I|%p|%S", "00|12|AM|60", &time))
        return 22;
    time.tm_hour = 12;
    return matches("%H|%I|%p", "12|12|PM", &time) ? 0 : 23;
}

static int leap(int year)
{
    return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
}

static char *digits(char *output, unsigned value, unsigned width)
{
    for (unsigned i = width; i; --i) {
        output[i - 1] = (char)('0' + value % 10);
        value /= 10;
    }
    return output + width;
}

static size_t expected_date(char *output, int year, int month, int day, int ordinal, int weekday)
{
    int monday_based = (weekday + 6) % 7;
    int thursday = ordinal + 3 - monday_based;
    int days = 365 + leap(year);
    int iso_year = year;
    if (thursday < 0) {
        --iso_year;
        thursday += 365 + leap(iso_year);
    } else if (thursday >= days) {
        ++iso_year;
        thursday -= days;
    }
    char *end = digits(output, (unsigned)iso_year, 4);
    *end++ = '-';
    *end++ = 'W';
    end = digits(end, (unsigned)(1 + thursday / 7), 2);
    *end++ = '-';
    end = digits(end, (unsigned)monday_based + 1, 1);
    *end++ = '|';
    end = digits(end, (unsigned)year, 4);
    *end++ = '-';
    end = digits(end, (unsigned)month + 1, 2);
    *end++ = '-';
    end = digits(end, (unsigned)day, 2);
    *end++ = '|';
    end = digits(end, (unsigned)ordinal + 1, 3);
    *end++ = '|';
    end = digits(end, (unsigned)(ordinal + 7 - weekday) / 7, 2);
    *end++ = '|';
    end = digits(end, (unsigned)(ordinal + 7 - monday_based) / 7, 2);
    *end++ = '|';
    end = digits(end, (unsigned)weekday, 1);
    *end++ = '|';
    end = digits(end, (unsigned)iso_year % 100, 2);
    *end = '\0';
    return (size_t)(end - output);
}

static int gregorian_cycle(void)
{
    static const int months[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    int weekday = 6; /* Saturday, 2000-01-01. */
    unsigned checked = 0;
    for (int year = 2000; year < 2400; ++year) {
        int ordinal = 0;
        for (int month = 0; month < 12; ++month) {
            int last = months[month] + (month == 1 && leap(year));
            for (int day = 1; day <= last; ++day) {
                char wanted[64], output[64];
                size_t count = expected_date(wanted, year, month, day, ordinal, weekday);
                struct tm date = {.tm_year = year - 1900, .tm_mon = month, .tm_mday = day,
                                  .tm_yday = ordinal, .tm_wday = weekday, .tm_isdst = -1};
                errno = EDOM;
                if (strftime(output, sizeof output, "%G-W%V-%u|%F|%j|%U|%W|%w|%g", &date) != count ||
                    !bytes_equal(output, wanted, count + 1) || errno != EDOM)
                    return 31;
                weekday = (weekday + 1) % 7;
                ++ordinal;
                ++checked;
            }
        }
    }
    return checked == 146097 && weekday == 6 ? 0 : 32;
}

static int bounds(void)
{
    char output[20];
    for (size_t i = 0; i < sizeof output; ++i)
        output[i] = '#';
    errno = EDOM;
    if (strftime(output + 1, 0, "%F", &sample) || output[1] != '#')
        return 41;
    if (strftime(output + 1, 11, "%F", &sample) != 10 ||
        !bytes_equal(output + 1, "2020-02-09", 11) || output[0] != '#' || output[12] != '#')
        return 42;
    output[11] = '$';
    if (strftime(output + 1, 10, "%F", &sample) || output[0] != '#' || output[11] != '$')
        return 43;
    return matches("", "", &sample) && errno == EDOM ? 0 : 44;
}

static int offset_only(void)
{
    struct tm date = sample;
    date.tm_gmtoff = -12679;
    if (!matches("[%z]", "[]", &date))
        return 55;
    date.tm_isdst = 1;
    if (!matches("[%z]", "[-0331]", &date))
        return 56;
    date.tm_gmtoff = 5 * 3600 + 45 * 60;
    return matches("[%z]", "[+0545]", &date) ? 0 : 57;
}

static int zone(void)
{
    struct tm date = sample;
    if (!matches("[%z|%Z]", "[|]", &date))
        return 51;
    date.tm_isdst = 1;
    date.tm_gmtoff = -12679;
    date.tm_zone = "TST";
    if (!matches("[%z|%Z]", "[-0331|TST]", &date))
        return 52;
    date.tm_gmtoff = 5 * 3600 + 45 * 60;
    date.tm_zone = NULL;
    if (!matches("[%z|%Z]", "[+0545|]", &date))
        return 53;
    date.tm_gmtoff = 100 * 3600;
    return matches("[%z]", "[]", &date) ? 0 : 54;
}

static int extended(void)
{
    struct tm date = sample;
    date.tm_year = -1901;
    if (!matches("%Y|%y|%F", "-0001|99|-0001-02-09", &date))
        return 61;
    date.tm_year = INT_MAX;
    if (!matches("%Y|%y", "2147485547|47", &date))
        return 62;
    date.tm_year = INT_MIN;
    if (!matches("%Y|%y", "-2147481748|52", &date))
        return 63;
    static const char *const bad[] = {"%Q", "trailing%", "%EG"};
    char output[20];
    errno = EDOM;
    for (size_t i = 0; i < sizeof bad / sizeof bad[0]; ++i) {
        if (strftime(output, sizeof output, bad[i], &sample) || errno != EDOM)
            return 64;
    }
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (strcmp(argv[1], "directives") == 0)
        return directives();
    if (strcmp(argv[1], "cycle") == 0)
        return gregorian_cycle();
    if (strcmp(argv[1], "bounds") == 0)
        return bounds();
    if (strcmp(argv[1], "zone") == 0)
        return zone();
    if (strcmp(argv[1], "offset") == 0)
        return offset_only();
    if (strcmp(argv[1], "extended") == 0)
        return extended();
    return 91;
}
