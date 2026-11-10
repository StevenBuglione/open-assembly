#define _GNU_SOURCE
#include <errno.h>
#include <limits.h>
#include <locale.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <wchar.h>

#ifdef OA_PHASE9_HOST
#include <sys/mman.h>
#else
extern long __al_syscall(long, long, long, long, long, long, long);
struct aux_entry { unsigned long type, value; };
extern const struct aux_entry *const __al_auxv;
#endif

enum operation {
    LEN, CMP, NCMP, CPY, NCPY, CAT, NCAT, CHR, RCHR, SPN, CSPN, PBRK, STR, TOK, COLL,
    XFRM, MEMCHR, MEMCMP, MEMCPY, MEMMOVE, MEMSET, OPERATIONS
};

static const char *const names[] = {
    "wcslen", "wcscmp", "wcsncmp", "wcscpy", "wcsncpy", "wcscat", "wcsncat", "wcschr",
    "wcsrchr", "wcsspn", "wcscspn", "wcspbrk", "wcsstr", "wcstok", "wcscoll", "wcsxfrm",
    "wmemchr", "wmemcmp", "wmemcpy", "wmemmove", "wmemset",
};

enum { GUARDS = 3, PAD = 0x77777777 };
static wchar_t *pages[GUARDS];
static size_t page_size;

static int create_pages(void)
{
#ifdef OA_PHASE9_HOST
    long actual = sysconf(_SC_PAGESIZE);
    if (actual <= 0)
        return 0;
    page_size = (size_t)actual;
#else
    for (const struct aux_entry *entry = __al_auxv; entry->type; ++entry) {
        if (entry->type == 6)  /* AT_PAGESZ */
            page_size = entry->value;
    }
#endif
    if (page_size < 4096)
        return 0;
    for (int i = 0; i < GUARDS; ++i) {
#ifdef OA_PHASE9_HOST
        char *raw = mmap(NULL, 3 * page_size, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (raw == MAP_FAILED || mprotect(raw + page_size, page_size, PROT_READ | PROT_WRITE))
            return 0;
#else
        enum { SYS_MMAP = 9, SYS_MPROTECT = 10 };
        long address = __al_syscall(SYS_MMAP, 0, 3 * page_size, 0, 0x22, -1, 0);
        if (address < 0 || __al_syscall(SYS_MPROTECT, address + page_size, page_size, 3, 0, 0, 0))
            return 0;
        char *raw = (char *)address;
#endif
        pages[i] = (wchar_t *)(raw + page_size);
    }
    return 1;
}

static int destroy_pages(void)
{
    for (int i = 0; i < GUARDS; ++i) {
        char *start = (char *)pages[i] - page_size;
#ifdef OA_PHASE9_HOST
        if (munmap(start, 3 * page_size))
#else
        if (__al_syscall(11, (long)start, 3 * page_size, 0, 0, 0, 0))  /* munmap */
#endif
            return 0;
    }
    return 1;
}

static wchar_t *edge(int page, size_t length, int right)
{
    return pages[page] + (right ? page_size / sizeof(wchar_t) - length : 0);
}

static int same(const wchar_t *a, const wchar_t *b, size_t length)
{
    for (size_t i = 0; i < length; ++i) {
        if (a[i] != b[i])
            return 0;
    }
    return 1;
}

static void copy(wchar_t *a, const wchar_t *b, size_t length)
{
    for (size_t i = 0; i < length; ++i)
        a[i] = b[i];
}

static int unchanged_neighbor(const wchar_t *a, size_t length, int right)
{
    return (right ? a[-1] : a[length]) == PAD;
}

static int directed(enum operation operation, int right)
{
    static const wchar_t standard[] = {L'a', 0x1f642, L'a', 0x100, L'b', 0};
    static const wchar_t altered[] = {L'a', 0x1f642, L'a', 0x100, L'c', 0};
    const size_t length = sizeof standard / sizeof standard[0];
    wchar_t *a = edge(0, length, right), *b = edge(1, length, right);
    wchar_t *blocked = edge(1, 0, 1);
    wchar_t *output = edge(2, length, right);
    copy(a, standard, length);
    copy(b, altered, length);
    for (size_t i = 0; i < page_size / sizeof(wchar_t); ++i)
        pages[2][i] = PAD;
    errno = EDOM;
    switch (operation) {
    case LEN:
        return wcslen(a) == length - 1 && wcslen(a + length - 1) == 0;
    case CMP:
    case NCMP:
    case MEMCMP:
        if (operation == NCMP &&
            (wcsncmp(a, b, length - 2) || wcsncmp(a, b, SIZE_MAX) >= 0 ||
             wcsncmp(blocked, blocked, 0)))
            return 0;
        if (operation == MEMCMP &&
            (wmemcmp(a, b, length - 2) || wmemcmp(a, b, length) >= 0 ||
             wmemcmp(blocked, blocked, 0)))
            return 0;
        a[0] = WCHAR_MIN;
        b[0] = WCHAR_MAX;
        if (operation == CMP)
            return wcscmp(a, b) < 0 && wcscmp(b, a) > 0 && !wcscmp(a, a);
        if (operation == NCMP)
            return wcsncmp(a, b, 1) < 0 && wcsncmp(b, a, 1) > 0;
        if (wmemcmp(a, b, 1) >= 0 || wmemcmp(b, a, 1) <= 0)
            return 0;
        a[0] = 0;
        return wmemcmp(a, b, 1) < 0 && wmemcmp(b, a, 1) > 0 && !wmemcmp(a, a, length);
    case CPY:
        return wcscpy(output, a) == output && same(output, standard, length) &&
               unchanged_neighbor(output, length, right);
    case NCPY: {
        wchar_t *small = edge(0, 3, right);
        copy(small, standard, 3);  /* no NUL in the bounded source */
        wchar_t *three = edge(2, 3, right);
        if (wcsncpy(three, small, 3) != three || !same(three, standard, 3) ||
            !unchanged_neighbor(three, 3, right) || wcsncpy(blocked, blocked + 1, 0) != blocked)
            return 0;
        static const wchar_t padded[] = {L'Z', 0, 0, 0, 0, 0};
        wchar_t *short_string = edge(1, 2, right);
        copy(short_string, padded, 2);
        return wcsncpy(output, short_string, length) == output && same(output, padded, length);
    }
    case CAT:
    case NCAT: {
        output[0] = L'z';
        output[1] = 0;
        if (operation == CAT)
            return wcscat(output, a + 1) == output && output[0] == L'z' &&
                   same(output + 1, standard + 1, length - 1) &&
                   unchanged_neighbor(output, length, right);
        wchar_t *nonterminated = edge(1, length - 2, right);
        copy(nonterminated, standard + 1, length - 2);
        if (wcsncat(output, nonterminated, length - 2) != output || output[0] != L'z' ||
            !same(output + 1, standard + 1, length - 1) ||
            wcsncat(output, blocked, 0) != output || !unchanged_neighbor(output, length, right))
            return 0;
        output[1] = 0;
        return wcsncat(output, a + 1, SIZE_MAX) == output &&
               same(output + 1, standard + 1, length - 1);
    }
    case CHR:
        return wcschr(a, L'a') == a && wcschr(a, 0) == a + length - 1 &&
               wcschr(a, 0x100) == a + 3 && wcschr(a, L'z') == NULL;
    case RCHR:
        return wcsrchr(a, L'a') == a + 2 && wcsrchr(a, 0) == a + length - 1 &&
               wcsrchr(a, 0x100) == a + 3 && wcsrchr(a, L'z') == NULL;
    case SPN:
    case CSPN:
    case PBRK: {
        wchar_t *set = edge(1, 3, right);
        const wchar_t accepted[] = {0x1f642, L'a', 0};
        copy(set, accepted, 3);
        if (operation == SPN)
            return wcsspn(a, set) == 3 && wcsspn(a, set + 2) == 0;
        set[0] = L'c';
        set[1] = 0x100;
        if (operation == CSPN)
            return wcscspn(a, set) == 3 && wcscspn(a, set + 2) == length - 1;
        return wcspbrk(a, set) == a + 3 && wcspbrk(a, set + 2) == NULL;
    }
    case STR: {
        wchar_t *needle = edge(1, 4, right);
        const wchar_t pattern[] = {L'a', 0x100, L'b', 0};
        copy(needle, pattern, 4);
        if (wcsstr(a, needle) != a + 2 || wcsstr(a, needle + 3) != a)
            return 0;
        needle[2] = L'x';
        return wcsstr(a, needle) == NULL;
    }
    case TOK: {
        wchar_t *words = edge(0, 9, right), *other = edge(1, 4, right);
        const wchar_t first[] = {L',', 0x100, L',', L',', L'b', L':', L'c', L':', 0};
        const wchar_t second[] = {L'x', L',', L'y', 0};
        copy(words, first, 9);
        copy(other, second, 4);
        wchar_t *state = NULL, *independent = NULL;
        return wcstok(words, L",", &state) == words + 1 && words[2] == 0 &&
               wcstok(other, L",", &independent) == other && other[1] == 0 &&
               wcstok(NULL, L",:", &state) == words + 4 && words[3] == L',' && words[5] == 0 &&
               wcstok(NULL, L":", &state) == words + 6 && words[7] == 0 &&
               wcstok(NULL, L":", &state) == NULL &&
               wcstok(NULL, L",", &independent) == other + 2 &&
               wcstok(NULL, L",", &independent) == NULL;
    }
    case COLL:
        return wcscoll(a, b) < 0 && wcscoll(b, a) > 0 && !wcscoll(a, a);
    case XFRM:
        if (wcsxfrm(NULL, a, 0) != length - 1 || wcsxfrm(output, a, length - 1) != length - 1)
            return 0;
#ifndef OA_PHASE9_HOST
        for (size_t i = 0; i < length; ++i) {
            if (output[i] != PAD)
                return 0;
        }
#endif
        if (wcsxfrm(output, a, length) != length - 1 || !same(output, standard, length))
            return 0;
        output[0] = PAD;
        return wcsxfrm(output, a, SIZE_MAX) == length - 1 &&
               same(output, standard, length) && unchanged_neighbor(output, length, right);
    case MEMCHR:
        a[1] = 0;
        return wmemchr(a, L'b', length) == a + 4 && wmemchr(a, 0, length) == a + 1 &&
               wmemchr(a, L'b', length - 2) == NULL && wmemchr(blocked, 0, 0) == NULL;
    case MEMCPY:
        return wmemcpy(output, a, length) == output && same(output, standard, length) &&
               wmemcpy(blocked, blocked + 1, 0) == blocked && unchanged_neighbor(output, length, right);
    case MEMMOVE:
        copy(output, standard, length);
        if (wmemmove(output + 1, output, length - 1) != output + 1 ||
            !same(output + 1, standard, length - 1) || output[0] != standard[0])
            return 0;
        copy(output, standard, length);
        return wmemmove(output, output + 1, length - 1) == output &&
               same(output, standard + 1, length - 1) && output[length - 1] == standard[length - 1] &&
               wmemmove(blocked, blocked, 0) == blocked && unchanged_neighbor(output, length, right);
    case MEMSET:
        if (wmemset(output, WCHAR_MIN + 17, length) != output ||
            wmemset(blocked, WCHAR_MAX, 0) != blocked || !unchanged_neighbor(output, length, right))
            return 0;
        for (size_t i = 0; i < length; ++i) {
            if (output[i] != WCHAR_MIN + 17)
                return 0;
        }
        return 1;
    case OPERATIONS:
        break;
    }
    return 0;
}

static uint32_t seed = UINT32_C(0x613c95ab);

static uint32_t next(void)
{
    seed ^= seed << 13;
    seed ^= seed >> 17;
    seed ^= seed << 5;
    return seed;
}

static int sign(int result)
{
    return (result > 0) - (result < 0);
}

static int compare(const wchar_t *a, const wchar_t *b, size_t n, int string)
{
    for (size_t i = 0; i < n; ++i) {
        if (a[i] != b[i])
            return a[i] > b[i] ? 1 : -1;
        if (string && !a[i])
            return 0;
    }
    return 0;
}

static int member(wchar_t value, const wchar_t *set, size_t size)
{
    for (size_t j = 0; j < size; ++j) {
        if (set[j] == value)
            return 1;
    }
    return 0;
}

static size_t span(const wchar_t *a, const wchar_t *b, size_t size, int expected_member)
{
    size_t i = 0;
    while (a[i] && member(a[i], b, size) == expected_member)
        ++i;
    return i;
}

static int tokens(wchar_t *text, size_t length, const wchar_t *set, size_t set_size)
{
    wchar_t expected[32];
    copy(expected, text, length + 1);
    size_t cursor = 0;
    wchar_t *input = text, *state = NULL;
    for (;;) {
        while (cursor < length && member(expected[cursor], set, set_size))
            ++cursor;
        wchar_t *token = wcstok(input, set, &state);
        input = NULL;
        if (cursor == length)
            return token == NULL && same(text, expected, length + 1);
        if (token != text + cursor)
            return 0;
        while (cursor < length && !member(expected[cursor], set, set_size))
            ++cursor;
        if (cursor < length)
            expected[cursor++] = 0;
    }
}

static int sample(enum operation operation)
{
    static const wchar_t alphabet[] = {L'A', L'B', 0xff, 0x100, 0x10000, 0x1f642, 0x10ffff};
    wchar_t a[32] = {0}, b[32] = {0}, out[65], expected[64];
    size_t m = next() % 32, n = next() % 32, limit = next() % 32;
    for (size_t i = 0; i < m; ++i)
        a[i] = alphabet[next() % 7];
    for (size_t i = 0; i < n; ++i)
        b[i] = alphabet[next() % 7];
    if (next() & 1) {
        size_t offset = next() % (m + 1);
        n = next() % (m - offset + 1);
        copy(b, a + offset, n);
        b[n] = 0;
    }
    for (size_t i = 0; i < sizeof out / sizeof out[0]; ++i)
        out[i] = PAD;
    wchar_t target = next() % 4 ? alphabet[next() % 7] : 0;
    errno = EDOM;
    switch (operation) {
    case LEN:
        return wcslen(a) == m;
    case CMP:
        return sign(wcscmp(a, b)) == compare(a, b, 32, 1);
    case NCMP:
        return sign(wcsncmp(a, b, limit)) == compare(a, b, limit, 1);
    case MEMCMP:
        return sign(wmemcmp(a, b, limit)) == compare(a, b, limit, 0);
    case COLL:
        return sign(wcscoll(a, b)) == compare(a, b, 32, 1);
    case CPY:
        return wcscpy(out, a) == out && same(out, a, m + 1) && out[m + 1] == PAD;
    case NCPY:
        for (size_t i = 0; i < limit; ++i)
            expected[i] = i < m ? a[i] : 0;
        return wcsncpy(out, a, limit) == out && same(out, expected, limit) && out[limit] == PAD;
    case CAT:
    case NCAT: {
        copy(out, a, m + 1);
        size_t take = operation == NCAT && limit < n ? limit : n;
        wchar_t *result = operation == CAT ? wcscat(out, b) : wcsncat(out, b, limit);
        return result == out && same(out, a, m) && same(out + m, b, take) &&
               out[m + take] == 0 && out[m + take + 1] == PAD;
    }
    case CHR:
    case RCHR:
    case MEMCHR: {
        size_t bound = operation == MEMCHR ? limit : m + 1;
        wchar_t *found = NULL;
        for (size_t i = 0; i < bound; ++i) {
            if (a[i] == target) {
                found = a + i;
                if (operation != RCHR)
                    break;
            }
        }
        if (operation == CHR)
            return wcschr(a, target) == found;
        if (operation == RCHR)
            return wcsrchr(a, target) == found;
        return wmemchr(a, target, limit) == found;
    }
    case SPN:
        return wcsspn(a, b) == span(a, b, n, 1);
    case CSPN:
        return wcscspn(a, b) == span(a, b, n, 0);
    case PBRK: {
        size_t index = span(a, b, n, 0);
        return wcspbrk(a, b) == (index == m ? NULL : a + index);
    }
    case STR: {
        wchar_t *found = NULL;
        for (size_t i = 0; i <= m && n <= m - i; ++i) {
            if (same(a + i, b, n)) {
                found = a + i;
                break;
            }
        }
        return wcsstr(a, b) == found;
    }
    case XFRM:
        return wcsxfrm(out, a, m + 1) == m && same(out, a, m + 1) && out[m + 1] == PAD;
    case MEMCPY:
        return wmemcpy(out, a, limit) == out && same(out, a, limit) && out[limit] == PAD;
    case MEMMOVE: {
        size_t from = next() % 32, to = next() % 32;
        for (size_t i = 0; i < 64; ++i)
            out[i] = expected[i] = alphabet[next() % 7];
        wchar_t original[32];
        copy(original, out + from, limit);
        copy(expected + to, original, limit);
        return wmemmove(out + to, out + from, limit) == out + to &&
               same(out, expected, 64) && out[64] == PAD;
    }
    case MEMSET:
        if (wmemset(out, target, limit) != out || out[limit] != PAD)
            return 0;
        for (size_t i = 0; i < limit; ++i) {
            if (out[i] != target)
                return 0;
        }
        return 1;
    case TOK:
        return tokens(a, m, b, n);
    case OPERATIONS:
        break;
    }
    return 0;
}

static int errno_preserved(void)
{
#ifdef OA_PHASE9_HOST
    return 1;
#else
    return errno == EDOM;
#endif
}

int main(int argc, char **argv)
{
    _Static_assert(sizeof(wchar_t) == 4 && WCHAR_MIN < 0, "LP64 signed wide element");
    if (argc != 3 || !setlocale(LC_ALL, argv[2]) || !create_pages())
        return 90;
    for (enum operation operation = LEN; operation < OPERATIONS; ++operation) {
        if (strcmp(argv[1], names[operation]))
            continue;
        for (int right = 0; right < 2; ++right) {
            if (!directed(operation, right) || !errno_preserved())
                return 10 + operation;
        }
        for (int i = 0; i < 512; ++i) {
            if (!sample(operation) || !errno_preserved())
                return 40 + operation;
        }
        return destroy_pages() ? 0 : 91;
    }
    return 92;
}
