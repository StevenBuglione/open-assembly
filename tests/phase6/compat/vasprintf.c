#include "../kernel_abi.h"
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

static int render(char **output, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = vasprintf(output, format, arguments);
    va_end(arguments);
    return result;
}

static int plain(void)
{
    char *output = NULL;
    int count = -1;
    int length = render(&output, "%s:%05d%n:%x", "abc", -27, &count, 0x5aU);
    if (length != 12 || !output || count != 9 ||
        !same_text(output, "abc:-0027:5a"))
        return 11;
    free(output);
    output = NULL;
    length = render(&output, "");
    if (length || !output || output[0])
        return 12;
    free(output);
    return 0;
}

static int alias(void)
{
    char input[] = "abc";
    char *output = NULL;
    errno = TEST_ERRNO;
    int length = render(&output, "%s%hhn:%s%1500u", input, (signed char *)&input[1], input, 9U);
    static const char prefix[] = {'a', 'b', 'c', ':', 'a', 3, 'c'};
    if (!output || length != 1507 || errno != TEST_ERRNO || input[1] != 3)
        return 21;
    for (size_t i = 0; i < sizeof prefix; ++i) {
        if (output[i] != prefix[i])
            return 22;
    }
    for (int i = 7; i < length - 1; ++i) {
        if (output[i] != ' ')
            return 23;
    }
    if (output[length - 1] != '9' || output[length] != '\0')
        return 24;
    free(output);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    if (same_text(argv[1], "plain")) return plain();
    if (same_text(argv[1], "alias")) return alias();
    return 2;
}
