#include "tree.h"

#include <dirent.h>
#include <errno.h>
#include <glob.h>
#include <string.h>

extern struct dirent *__real_readdir(DIR *);
static int inject, observed, reports, stop, nested, nested_ok, seen_error;
static const char *expected_path;

struct dirent *__wrap_readdir(DIR *directory)
{
    if (inject && observed) {
        ++observed;
        errno = EIO;
        return NULL;
    }
    struct dirent *entry = __real_readdir(directory);
    if (inject && entry && (!strcmp(entry->d_name, "a.txt") || !strcmp(entry->d_name, "B.txt")))
        ++observed;
    return entry;
}

static int on_error(const char *path, int error)
{
    ++reports;
    if (strcmp(path, expected_path))
        return 1;
    seen_error = error;
    if (nested) {
        glob_t inside = {0};
        nested_ok = glob("root/a.txt", 0, NULL, &inside) == 0 && inside.gl_pathc == 1 &&
                    inside.gl_pathv && !strcmp(inside.gl_pathv[0], "root/a.txt");
        globfree(&inside);
    }
    return stop;
}

static int original(const glob_t *result)
{
    return result->gl_pathc == 2 && result->gl_pathv &&
           !strcmp(result->gl_pathv[0], "root/B.txt") && !strcmp(result->gl_pathv[1], "root/a.txt") &&
           !result->gl_pathv[2];
}

static int missing(void)
{
    glob_t result = {0};
    expected_path = "root/missing/";
    nested = 1;
    errno = EDOM;
    if (glob("root/missing/*.txt", 0, on_error, &result) != GLOB_NOMATCH || reports != 1 ||
        seen_error != ENOENT || !nested_ok || errno != EDOM || result.gl_pathc)
        return 11;
    globfree(&result);

    if (glob("root/*.txt", 0, NULL, &result) || !original(&result))
        return 90;
    reports = seen_error = 0;
    if (glob("root/missing/*.txt", GLOB_APPEND | GLOB_ERR, on_error, &result) != GLOB_ABORTED ||
        reports != 1 || seen_error != ENOENT || !original(&result))
        return 12;
    reports = seen_error = 0;
    stop = 1;
    if (glob("root/missing/*.txt", GLOB_APPEND, on_error, &result) != GLOB_ABORTED ||
        reports != 1 || seen_error != ENOENT || !original(&result))
        return 13;
    globfree(&result);

    expected_path = "root/a.txt/";
    reports = 0;
    errno = EDOM;
    int status = glob("root/a.txt/*.txt", 0, on_error, &result);
    int valid = status == GLOB_NOMATCH && !reports && !result.gl_pathc && errno == EDOM;
    globfree(&result);
    return valid ? 0 : 14;
}

static int late_error(void)
{
    glob_t result = {0};
    expected_path = "root/";
    inject = 1;
    int status = glob("root/*.txt", GLOB_ERR, on_error, &result);
    inject = 0;
    int valid = status == GLOB_ABORTED && reports == 1 && seen_error == EIO && observed == 2 &&
                result.gl_pathc == 1 && result.gl_pathv && result.gl_pathv[0] &&
                (!strcmp(result.gl_pathv[0], "root/a.txt") || !strcmp(result.gl_pathv[0], "root/B.txt")) &&
                !result.gl_pathv[1];
    globfree(&result);
    return valid ? 0 : 15;
}

int main(int argc, char **argv)
{
    if (argc != 2 || !basic_tree())
        return 90;
    if (!strcmp(argv[1], "missing"))
        return missing();
    if (!strcmp(argv[1], "late-error"))
        return late_error();
    return 91;
}
