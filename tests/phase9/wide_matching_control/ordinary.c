#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <wchar.h>

enum { WORDS = 16, MARK = 0x31415926, TEST_ERRNO = 947 };

static size_t length(const volatile wchar_t *words, size_t capacity)
{
    for (size_t i = 0; i < capacity; ++i)
        if (!words[i])
            return i;
    return SIZE_MAX;
}

static wchar_t *first_match(wchar_t *text, size_t text_size, wchar_t *needle, size_t needle_size)
{
    const volatile wchar_t *source = text;
    const volatile wchar_t *target = needle;
    size_t n = length(source,text_size), m = length(target,needle_size);
    if (n == SIZE_MAX || m == SIZE_MAX || m > n)
        return NULL;
    for (size_t start = 0; start <= n - m; ++start) {
        size_t i = 0;
        while (i < m && source[start + i] == target[i])
            ++i;
        if (i == m)
            return text + start;
    }
    return NULL;
}

int main(void)
{
    _Static_assert(sizeof(wchar_t) == 4, "Linux wide elements");
    static const wchar_t original[WORDS] = {
        MARK,1,-1,1,-1,17,0,18,1,-1,17,0,1,-1,0,MARK,
    };
    static const wchar_t patterns[][8] = {
        {1,-1,17,0,18,1,-1,0},
        {1,-1,0,18,1,-1,17,0},
        {-1,17,0,1,-1,17,0,0},
        {17,0,-1,17,0,1,-1,0},
        {0,1,-1,17,0,18,0,0},
        {18,0,1,-1,17,0,0,0},
        {1,-1,1,-1,17,18,0,0},
        {1,-1,17,0,18,1,-1,0},
    };
    static const size_t offsets[] = {2,0,3,4,0,SIZE_MAX,SIZE_MAX,SIZE_MAX};
    for (size_t row = 0; row < sizeof patterns / sizeof *patterns; ++row) {
        wchar_t text[WORDS], needle[WORDS], expected[WORDS];
        volatile wchar_t *write_text = text, *write_needle = needle;
        for (size_t i = 0; i < WORDS; ++i) {
            write_text[i] = original[i];
            expected[i] = i >= 1 && i <= 8 ? patterns[row][i - 1] : MARK;
            write_needle[i] = expected[i];
        }
        size_t offset = row == 7 ? 6 : 1;
        wchar_t *wanted = first_match(text + offset,WORDS - offset,needle + 1,WORDS - 1);
        wchar_t *specified = offsets[row] == SIZE_MAX ? NULL : text + offset + offsets[row];
        if (wanted != specified)
            return 90;
        volatile int *error_cell = &errno;
        *error_cell = TEST_ERRNO;
        wchar_t *actual = wcsstr(text + offset,needle + 1);
        int error = *error_cell;
        if (actual != wanted)
            return 21;
        if (error != TEST_ERRNO)
            return 22;
        const volatile wchar_t *observed_text = text, *observed_needle = needle;
        for (size_t i = 0; i < WORDS; ++i)
            if (observed_text[i] != original[i] || observed_needle[i] != expected[i])
                return 23;
    }
    return 0;
}
