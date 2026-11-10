#include "../kernel_abi.h"

int main(void)
{
    char program[] = "test";
    char group[] = "-abVALUE", next[] = "-c", word[] = "other";
    char operand[] = "operand", later[] = "-a";
    char *arguments[] = {program, group, next, word, operand, later, NULL};

    optind = 0;
    opterr = 0;
    errno = TEST_ERRNO;
    if (getopt(6, arguments, "ab:c:") != 'a' || errno != TEST_ERRNO)
        return 11;
    if (getopt(6, arguments, "ab:c:") != 'b' || optind != 2 ||
        !optarg || !same_text(optarg, "VALUE"))
        return 12;
    if (getopt(6, arguments, "ab:c:") != 'c' || optind != 4 || optarg != word)
        return 13;
    if (getopt(6, arguments, "ab:c:") != -1 || optind != 4 ||
        arguments[4] != operand || arguments[5] != later)
        return 14;

    char terminator[] = "--";
    char *ended[] = {program, terminator, later, NULL};
    optind = 0;
    if (getopt(3, ended, "a") != -1 || optind != 2)
        return 15;

    char missing[] = "-b", unknown[] = "-z";
    char *errors[] = {program, unknown, missing, NULL};
    optind = 0;
    opterr = 1;
    if (getopt(3, errors, ":ab:") != '?' || optopt != 'z' || optind != 2)
        return 16;
    if (getopt(3, errors, ":ab:") != ':' || optopt != 'b' ||
        errno != TEST_ERRNO)
        return 17;
#if !defined(OA_PHASE6_HOST) || defined(__GLIBC__)
    if (optind != 3)
        return 20;
#endif

    optind = 0;
    if (getopt(6, arguments, "ab:c:") != 'a')
        return 18;
    optind = 0;
    char *reset[] = {program, later, NULL};
    if (getopt(2, reset, "a") != 'a' || getopt(2, reset, "a") != -1 || optind != 2)
        return 19;
    return 0;
}
