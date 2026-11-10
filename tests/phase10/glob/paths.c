#define _GNU_SOURCE
#include "tree.h"

#include <errno.h>
#include <glob.h>
#include <locale.h>
#include <stdio.h>
#include <string.h>

#ifndef OA_PHASE10_HOST
extern long __al_syscall(long, long, long, long, long, long, long);
#endif

static int make_link(const char *target, const char *link)
{
#ifdef OA_PHASE10_HOST
    return symlink(target, link) == 0;
#else
    return __al_syscall(88, (long)target, (long)link, 0, 0, 0, 0) == 0;
#endif
}

static int normalized(const char *left, const char *right)
{
    while (*left && *right) {
        if (*left != *right)
            return 0;
        if (*left == '/') {
            while (*left == '/')
                ++left;
            while (*right == '/')
                ++right;
        } else {
            ++left;
            ++right;
        }
    }
    return !*left && !*right;
}

static int listing(const glob_t *result, size_t offset, const char *const *paths, size_t count,
                   int exact)
{
    if (result->gl_pathc != count || !result->gl_pathv)
        return 0;
    for (size_t i = 0; i < offset; ++i)
        if (result->gl_pathv[i])
            return 0;
    for (size_t i = 0; i < count; ++i) {
        const char *actual = result->gl_pathv[offset + i];
        if (!actual || (exact ? strcmp(actual, paths[i]) != 0 : !normalized(actual, paths[i])))
            return 0;
    }
    return result->gl_pathv[offset + count] == NULL;
}

static int expand(const char *pattern, int flags, const char *const *paths, size_t count, int exact)
{
    glob_t result = {0};
    int valid = glob(pattern, flags, NULL, &result) == 0 && listing(&result, 0, paths, count, exact);
    globfree(&result);
    return valid;
}

static int paths(void)
{
    if (!basic_tree() || !make_file("root/[lit]") || !make_file("root/u\xc3\xa9") ||
        !make_file("root/uQ") || !make_link("dir", "root/link") ||
        !make_link("missing", "root/broken") || !make_link("a.txt", "root/filelink"))
        return 90;
    const char *plain[] = {"root/B.txt", "root/a.txt"};
    if (!expand("root/*.txt", 0, plain, 2, 1))
        return 11;
    const char *hidden[] = {"root/.dot.txt"};
    if (!expand("root/.*.txt", 0, hidden, 1, 1))
        return 12;
    const char *nested[] = {"root/dir/c.txt", "root/dir/d.txt"};
    if (!expand("root//dir//*.txt", 0, nested, 2, 0))
        return 13;
    const char *slash[] = {"root/dir/"};
    if (!expand("root//dir///", 0, slash, 1, 0))
        return 14;
    char cwd[2048], pattern[2100], first[2100], second[2100];
    if (!getcwd(cwd, sizeof cwd) || snprintf(pattern, sizeof pattern, "%s/root/dir/*.txt", cwd) <= 0 ||
        snprintf(first, sizeof first, "%s/root/dir/c.txt", cwd) <= 0 ||
        snprintf(second, sizeof second, "%s/root/dir/d.txt", cwd) <= 0)
        return 90;
    const char *absolute[] = {first, second};
    if (!expand(pattern, 0, absolute, 2, 1))
        return 15;
    const char *marked[] = {"root/filelink", "root/link/"};
    if (!expand("root/*link", GLOB_MARK, marked, 2, 1))
        return 16;
    const char *dangling[] = {"root/broken"};
    if (!expand("root/bro*", 0, dangling, 1, 1))
        return 17;
    glob_t empty = {0};
    int no_match = glob("root/bro*/", 0, NULL, &empty);
    globfree(&empty);
    if (no_match != GLOB_NOMATCH)
        return 18;
    const char *literal[] = {"root/[lit]"};
    if (!expand("root/\\[lit]", 0, literal, 1, 1))
        return 19;
    const char *fallback[] = {"root/unused-*.txt"};
    if (!expand("root/unused-*.txt", GLOB_NOCHECK, fallback, 1, 1))
        return 20;
    if (!setlocale(LC_CTYPE, "C.UTF-8"))
        return 90;
    const char *utf8[] = {"root/uQ", "root/u\xc3\xa9"};
    if (!expand("root/u?", 0, utf8, 2, 1))
        return 21;
    return 0;
}

static int batches(void)
{
    if (!basic_tree())
        return 90;
    const char *first[] = {"root/dir/c.txt", "root/dir/d.txt"};
    const char *both[] = {"root/dir/c.txt", "root/dir/d.txt", "root/B.txt", "root/a.txt"};
    glob_t result = {.gl_offs = 2};
    int valid = !glob("root/dir/*.txt", GLOB_DOOFFS, NULL, &result) && listing(&result, 2, first, 2, 1) &&
                !glob("root/*.txt", GLOB_APPEND | GLOB_DOOFFS, NULL, &result) &&
                listing(&result, 2, both, 4, 1);
    globfree(&result);
    return valid ? 0 : 22;
}

#ifndef OA_PHASE10_HOST
static int exact_spelling(void)
{
    if (!basic_tree())
        return 90;
    const char *paths[] = {"root//dir//c.txt", "root//dir//d.txt"};
    if (!expand("root//dir//*.txt", 0, paths, 2, 1))
        return 23;
    const char *slash[] = {"root//dir///"};
    if (!expand("root//dir///", 0, slash, 1, 1))
        return 24;
    const char *escaped[] = {"root/dir/c.txt"};
    if (!expand("root\\/dir/c.txt", 0, escaped, 1, 1))
        return 25;
    return 0;
}
#endif

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "paths"))
        return paths();
    if (!strcmp(argv[1], "batches"))
        return batches();
#ifndef OA_PHASE10_HOST
    if (!strcmp(argv[1], "spelling"))
        return exact_spelling();
#endif
    return 91;
}
