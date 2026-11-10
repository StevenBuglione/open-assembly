#include <errno.h>
#include <json.h>
#include <stdint.h>
#include <string.h>

extern long __al_syscall(long, long, long, long, long, long, long);

static int edge(const unsigned char *bytes, size_t *output, size_t *work, int right)
{
    static const size_t expected[] = {8, 0, 10, SIZE_MAX, 1, 1, 7, 0, 2, 8, 9, 0};
    errno = EDOM;
    if (json_scan_string(bytes, 7, 1) != 7 || json_scan_number(bytes, 9, 8) != 9 ||
        json_lex(bytes, 10, 1, output) || output[0] != 1 || output[1] != 1 || output[2] != 7)
        return 11;
    if (json_parse(bytes, 10, work, 1, output, 3) != 3 ||
        memcmp(output, expected, sizeof expected) || errno != EDOM)
        return 12;
    if (json_parse(bytes, 9, work, 1, output, 3) != -EILSEQ ||
        memcmp(output, expected, sizeof expected) || errno != EDOM)
        return 13;
    if (right) {
        /* The three-byte span is immediately before an inaccessible page. */
        const unsigned char *partial = bytes + 10;
        if (json_scan_string(partial, 3, 0) != -EILSEQ ||
            json_scan_string(partial + 3, 0, 0) != -EILSEQ ||
            json_scan_number(partial + 3, 0, 0) != -EILSEQ ||
            json_lex(partial + 3, 0, 0, output) || output[0] || output[1] || output[2])
            return 14;
    }
    return 0;
}

int main(void)
{
    enum { PAGE = 4096, PAGES = 7 };
    long address = __al_syscall(9, 0, PAGE * PAGES, 0, 0x22, -1, 0);
    if (address <= 0)
        return 90;
    unsigned char *mapping = (void *)(uintptr_t)address;
    unsigned char *bytes = mapping + PAGE, *output = mapping + 3 * PAGE, *work = mapping + 5 * PAGE;
    if (__al_syscall(10, (long)bytes, PAGE, 3, 0, 0, 0) ||
        __al_syscall(10, (long)output, PAGE, 3, 0, 0, 0) ||
        __al_syscall(10, (long)work, PAGE, 3, 0, 0, 0))
        return 91;
    const unsigned char sample[] = {'[', '"', 0xf0, 0x90, 0x80, 0x80, '"', ',', '7', ']'};
    memcpy(bytes, sample, sizeof sample);
    unsigned char *right = bytes + PAGE - sizeof sample - 3;
    memcpy(right, sample, sizeof sample);
    right[10] = '"';
    right[11] = 0xf0;
    right[12] = 0x90;
    if (__al_syscall(10, (long)bytes, PAGE, 1, 0, 0, 0))
        return 92;
    int result = edge(bytes, (size_t *)output, (size_t *)work, 0);
    if (!result)
        result = edge(right, (size_t *)(output + PAGE - 12 * sizeof(size_t)),
                      (size_t *)(work + PAGE - 5 * sizeof(size_t)), 1);
    return __al_syscall(11, address, PAGE * PAGES, 0, 0, 0, 0) ? 93 : result;
}
