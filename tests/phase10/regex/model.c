#include <regex.h>
#include <stddef.h>

static regoff_t longest(const char *text, regoff_t size, regoff_t start, unsigned pattern)
{
    regoff_t end = -1, cursor = start;
    if (pattern == 0 || pattern == 3) {
        while (cursor < size && text[cursor] == 'a')
            ++cursor;
        if (cursor < size && text[cursor] == 'b')
            end = cursor + 1;
        if (pattern == 0 && start < size && text[start] == 'a') {
            cursor = start + 1;
            while (cursor < size && text[cursor] == 'b')
                ++cursor;
            if (cursor > end)
                end = cursor;
        }
    } else if (pattern == 1) {
        for (unsigned count = 1; count <= 3 && cursor < size && text[cursor] != 'c'; ++count) {
            ++cursor;
            if (cursor < size && text[cursor] == 'c')
                end = cursor + 1;
        }
    } else if (start < size && text[start] == 'a') {
        for (cursor = start + 1; cursor < size; ++cursor)
            if (text[cursor] == 'c')
                end = cursor + 1;
    } else if (start < size && text[start] == 'b') {
        cursor = start;
        while (cursor < size && text[cursor] == 'b')
            ++cursor;
        end = cursor;
    }
    return end;
}

int main(void)
{
    const char *patterns[] = {"a*b|ab*", "[ab]{1,3}c", "a.*c|b+", "(a?)*b"};
    for (unsigned pattern = 0; pattern < sizeof patterns / sizeof patterns[0]; ++pattern) {
        regex_t expression = {0};
        if (regcomp(&expression, patterns[pattern], REG_EXTENDED))
            return 90;
        unsigned count = 1;
        for (regoff_t size = 0; size <= 7; ++size, count *= 3) {
            char text[8];
            text[size] = 0;
            for (unsigned value = 0; value < count; ++value) {
                unsigned index = value;
                for (regoff_t i = 0; i < size; ++i, index /= 3)
                    text[i] = (char)('a' + index % 3);
                regoff_t start = 0, end = -1;
                for (; start <= size; ++start)
                    if ((end = longest(text, size, start, pattern)) >= 0)
                        break;
                regmatch_t match;
                int status = regexec(&expression, text, 1, &match, 0);
                if (end < 0 ? status != REG_NOMATCH :
                    status || match.rm_so != start || match.rm_eo != end)
                    return 11 + (int)pattern;
            }
        }
        regfree(&expression);
    }
    return 0;
}
