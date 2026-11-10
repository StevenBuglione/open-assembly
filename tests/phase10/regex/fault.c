#include <errno.h>
#include <regex.h>
#include <stdlib.h>

extern void *__real_calloc(size_t, size_t);
static int armed, attempts;

void *__wrap_calloc(size_t count, size_t size)
{
    if (armed && !attempts++) {
        errno = ENOMEM;
        return NULL;
    }
    return __real_calloc(count, size);
}

int main(void)
{
    regex_t expression = {0};
    armed = 1;
    int result = regcomp(&expression, "^(ab|c){1,3}$", REG_EXTENDED);
    armed = 0;
    if (result != REG_ESPACE || !attempts)
        return 11;
    if (regcomp(&expression, "^(ab|c){1,3}$", REG_EXTENDED))
        return 12;
    regmatch_t match;
    result = regexec(&expression, "abcc", 1, &match, 0);
    regfree(&expression);
    return result || match.rm_so != 0 || match.rm_eo != 4 ? 13 : 0;
}
