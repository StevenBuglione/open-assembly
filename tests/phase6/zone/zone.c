#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

struct expected {
    time_t instant;
    long offset;
    int dst;
    const char *zone;
    int civil[8];
};

#include "tz_vectors.h"

static int matches(const struct tm *value, const struct expected *expected)
{
    int actual[] = {value->tm_year, value->tm_mon, value->tm_mday, value->tm_hour,
                    value->tm_min, value->tm_sec, value->tm_wday, value->tm_yday};
    return !memcmp(actual, expected->civil, sizeof actual) && value->tm_isdst == expected->dst &&
           value->tm_gmtoff == expected->offset && value->tm_zone &&
           !strcmp(value->tm_zone, expected->zone);
}

static int preserved_errno(void)
{
#ifdef OA_PHASE6_HOST
    /* The project promises errno preservation on successful zone conversions. */
    return 1;
#else
    return errno == EDOM;
#endif
}

static int check_rows(const struct expected *rows, size_t count)
{
    for (size_t i = 0; i < count; ++i) {
        struct tm result;
        errno = EDOM;
        if (localtime_r(&rows[i].instant, &result) != &result)
            return 11;
        if (!matches(&result, &rows[i]) || !preserved_errno())
            return 12 + (int)i;
    }
    return 0;
}

static int zone_file(const char *name)
{
    char path[4096];
    path[0] = ':';
    if (!getcwd(path + 1, sizeof path - 1))
        return 0;
    size_t used = strlen(path), count = strlen(name);
    if (used + count + 2 > sizeof path)
        return 0;
    path[used++] = '/';
    memcpy(path + used, name, count + 1);
    return setenv("TZ", path, 1) == 0;
}

static int table(const char *name)
{
#define TABLE(number) {#number, #number ".tzif", number, sizeof number / sizeof number[0]}
    static const struct {
        const char *name, *file;
        const struct expected *rows;
        size_t count;
    } fixtures[] = {TABLE(b1), TABLE(b2), TABLE(b3), TABLE(b4), TABLE(b5)};
#undef TABLE
    for (size_t i = 0; i < sizeof fixtures / sizeof fixtures[0]; ++i) {
        if (!strcmp(name, fixtures[i].name)) {
            if (!zone_file(fixtures[i].file))
                return 20;
            return check_rows(fixtures[i].rows, fixtures[i].count);
        }
    }
    return 91;
}

static int malformed(void)
{
    static const char *const paths[] = {
        "magic.tzif", "version.tzif", "short.tzif", "count.tzif", "index.tzif",
        "order.tzif", "designate.tzif", "dst.tzif", "missing.tzif", "directory", "oversized",
    };
    if (mkdir("directory", 0700))
        return 21;
    int fd = open("oversized", O_CREAT | O_EXCL | O_WRONLY, 0600);
    if (fd < 0 || lseek(fd, 1024 * 1024, SEEK_SET) != 1024 * 1024 ||
        write(fd, "X", 1) != 1 || close(fd))
        return 22;
    for (size_t i = 0; i < sizeof paths / sizeof paths[0]; ++i) {
        if (!zone_file(paths[i]) || check_rows(b1, 1))
            return 23 + (int)i;
    }
    return 0;
}

static int cache(void)
{
    static const struct expected east = {0, 20700, 0, "NPT", {70, 0, 1, 5, 45, 0, 4, 0}};
    static const struct expected west = {0, -12600, 0, "NST", {69, 11, 31, 20, 30, 0, 3, 364}};
    if (setenv("TZ", "NPT-5:45", 1))
        return 35;
    struct tm first;
    errno = EDOM;
    if (localtime_r(&east.instant, &first) != &first || !matches(&first, &east) ||
        check_rows(&east, 1) || strcmp(first.tm_zone, "NPT") || !preserved_errno())
        return 36;
    if (setenv("TZ", "NST3:30", 1) || check_rows(&west, 1))
        return 37;
    return 0;
}

static int utc_mktime(void)
{
    struct tm before = {
        .tm_year = 69, .tm_mon = 11, .tm_mday = 31, .tm_hour = 23,
        .tm_min = 59, .tm_sec = 59, .tm_wday = 99, .tm_yday = -1,
        .tm_isdst = -1, .tm_gmtoff = 123, .tm_zone = "input",
    };
    static const struct expected old = {-1, 0, 0, "UTC", {69, 11, 31, 23, 59, 59, 3, 364}};
    errno = EDOM;
    if (mktime(&before) != old.instant || !matches(&before, &old) || !preserved_errno())
        return 41;

    struct tm irregular = {
        .tm_year = 124, .tm_mon = 13, .tm_mday = 0, .tm_hour = 25,
        .tm_min = -61, .tm_sec = 120, .tm_wday = -1, .tm_yday = 800, .tm_isdst = -1,
    };
    static const struct expected normalized = {
        1738368060L, 0, 0, "UTC", {125, 1, 1, 0, 1, 0, 6, 31},
    };
    errno = EDOM;
    if (mktime(&irregular) != normalized.instant || !matches(&irregular, &normalized) ||
        !preserved_errno())
        return 42;
    return 0;
}

static int dst_mktime(int project)
{
    static const struct tm repeated = {
        .tm_year = 124, .tm_mon = 10, .tm_mday = 3, .tm_hour = 1, .tm_min = 30,
    };
    static const struct expected daylight = {
        1730611800L, -14400, 1, "EDT", {124, 10, 3, 1, 30, 0, 0, 307},
    };
    static const struct expected standard = {
        1730615400L, -18000, 0, "EST", {124, 10, 3, 1, 30, 0, 0, 307},
    };
    struct tm time = repeated;
    time.tm_isdst = 1;
    errno = EDOM;
    if (mktime(&time) != daylight.instant || !matches(&time, &daylight) || !preserved_errno())
        return 45;
    time = repeated;
    errno = EDOM;
    if (mktime(&time) != standard.instant || !matches(&time, &standard) || !preserved_errno())
        return 46;
    if (!project)
        return 0;

    time = repeated;
    time.tm_isdst = -1;
    errno = EDOM;
    if (mktime(&time) != daylight.instant || !matches(&time, &daylight) || !preserved_errno())
        return 47;
    time = (struct tm){
        .tm_year = 124, .tm_mon = 2, .tm_mday = 10, .tm_hour = 2, .tm_min = 30,
        .tm_isdst = -1,
    };
    static const struct expected skipped = {
        1710055800L, -14400, 1, "EDT", {124, 2, 10, 3, 30, 0, 0, 69},
    };
    errno = EDOM;
    if (mktime(&time) != skipped.instant || !matches(&time, &skipped) || !preserved_errno())
        return 48;
    return 0;
}

static int overflow(void)
{
    const time_t times[] = {LONG_MAX, LONG_MIN};
    for (size_t i = 0; i < sizeof times / sizeof times[0]; ++i) {
        struct tm time;
        unsigned char original[sizeof time];
        memset(&time, 0xa5, sizeof time);
        memcpy(original, &time, sizeof original);
        errno = EDOM;
        if (localtime_r(&times[i], &time) || errno != EOVERFLOW ||
            memcmp(&time, original, sizeof original))
            return 51 + (int)i;
    }

    const struct tm years[] = {
        {.tm_year = INT_MAX, .tm_mon = 12, .tm_mday = 1, .tm_isdst = -1},
        {.tm_year = INT_MIN, .tm_mon = -1, .tm_mday = 1, .tm_isdst = -1},
    };
    for (size_t i = 0; i < sizeof years / sizeof years[0]; ++i) {
        struct tm time;
        unsigned char original[sizeof time];
        memcpy(&time, &years[i], sizeof time);
        memcpy(original, &time, sizeof original);
        errno = EDOM;
        if (mktime(&time) != -1 || errno != EOVERFLOW ||
            memcmp(&time, original, sizeof original))
            return 53 + (int)i;
    }
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    const char *name = argv[1];
    if (!strcmp(name, "utc") || !strcmp(name, "utc-rule"))
        return check_rows(b1, 1);
    if (!strcmp(name, "new-york")) {
        if (!zone_file("new-york.tzif"))
            return 20;
        return check_rows(new_york, sizeof new_york / sizeof new_york[0]);
    }
    if (!strcmp(name, "julian"))
        return check_rows(julian, sizeof julian / sizeof julian[0]);
    if (!strcmp(name, "yearday"))
        return check_rows(yearday, sizeof yearday / sizeof yearday[0]);
    if (!strcmp(name, "malformed"))
        return malformed();
    if (!strcmp(name, "cache"))
        return cache();
    if (!strcmp(name, "mktime-utc"))
        return utc_mktime();
    if (!strcmp(name, "mktime-dst"))
        return dst_mktime(0);
    if (!strcmp(name, "mktime-policy"))
        return dst_mktime(1);
    if (!strcmp(name, "overflow"))
        return overflow();
    return table(name);
}
