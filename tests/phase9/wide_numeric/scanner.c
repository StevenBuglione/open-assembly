#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <locale.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <wchar.h>

extern long __al_syscall(long, long, long, long, long, long, long);
struct aux_entry { unsigned long type, value; };
extern const struct aux_entry *const __al_auxv;

struct vector {
    const wchar_t *text;
    int base;
    unsigned end;
    int64_t signed_value;
    uint64_t unsigned_value;
    int signed_errno, unsigned_errno;
};

#define BOTH(input, base, end, value) {input, base, end, value, (uint64_t)(value), EDOM, EDOM}
#define NONE(input, base) {input, base, 0, 0, 0, EINVAL, EINVAL}

static const struct vector c_locale[] = {
    BOTH(L"  -123z", 10, 6, -123),
    BOTH(L"\t+42!", 0, 4, 42),
    BOTH(L"0xFz", 0, 3, 15),
    BOTH(L"0XAfQ", 16, 4, 175),
    BOTH(L"0x:", 0, 1, 0),
    BOTH(L"0x:", 16, 1, 0),
    BOTH(L"0x", 0, 1, 0),
    BOTH(L"0", 0, 1, 0),
    BOTH(L"0108", 0, 3, 8),
    BOTH(L"0b11", 0, 1, 0),
    BOTH(L"Zz!", 36, 2, 1295),
    BOTH(L"0x\u0130", 0, 1, 0),
    BOTH(L"0\u0178F", 0, 1, 0),
    BOTH(L"12\u0141", 36, 2, 38),
    BOTH(L"12\u0131", 10, 2, 12),
    BOTH(L"0A", 10, 1, 0),
    BOTH(L"\v+001F!", 16, 6, 31),
    NONE(L"", 10),
    NONE(L"+", 10),
    NONE(L"0", 1),
    NONE(L"1", -1),
    NONE(L"1", 37),
    NONE(L"\u0100", 10),
    NONE(L"\u0131", 10),
    NONE(L"\u200312", 10),
    NONE(L"@", 36),
    NONE(L"`", 36),
    NONE(L":", 16),
    NONE(L"\x0e" L"1", 10),
    BOTH(L"9223372036854775807", 10, 19, INT64_MAX),
    BOTH(L"-9223372036854775808", 10, 20, INT64_MIN),
    {L"9223372036854775808!", 10, 19, INT64_MAX, UINT64_C(9223372036854775808), ERANGE, EDOM},
    {L"-9223372036854775809!", 10, 20, INT64_MIN, UINT64_C(9223372036854775807), ERANGE, EDOM},
    {L"18446744073709551615?", 10, 20, INT64_MAX, UINT64_MAX, ERANGE, EDOM},
    {L"18446744073709551616?", 10, 20, INT64_MAX, UINT64_MAX, ERANGE, ERANGE},
    {L"-18446744073709551616000?", 10, 24, INT64_MIN, UINT64_MAX, ERANGE, ERANGE},
    {L"0xFFFFFFFFFFFFFFFFg", 0, 18, INT64_MAX, UINT64_MAX, ERANGE, EDOM},
    {L"0x10000000000000000g", 16, 19, INT64_MAX, UINT64_MAX, ERANGE, ERANGE},
};

static const struct vector utf8_locale[] = {
    BOTH(L"\u2003-0XAf!", 0, 6, -175),
    BOTH(L"\u3000+0108", 0, 5, 8),
    BOTH(L"\u2028\t+2", 10, 4, 2),
    BOTH(L"\u00a012", 10, 3, 12),
    NONE(L"\u200b12", 10),
    NONE(L"\u2003+", 10),
};

static int verify(const struct vector *vector, const wchar_t *text)
{
    wchar_t sentinel;
    wchar_t *end;
#define CHECK(function, expected, error) do { \
    errno = EDOM; \
    end = &sentinel; \
    if ((uint64_t)function(text, &end, vector->base) != (uint64_t)(expected) || \
        errno != (error) || end != text + vector->end) \
        return 0; \
} while (0)
    CHECK(wcstol, vector->signed_value, vector->signed_errno);
    CHECK(wcstoll, vector->signed_value, vector->signed_errno);
    CHECK(wcstoimax, vector->signed_value, vector->signed_errno);
    CHECK(wcstoul, vector->unsigned_value, vector->unsigned_errno);
    CHECK(wcstoull, vector->unsigned_value, vector->unsigned_errno);
    CHECK(wcstoumax, vector->unsigned_value, vector->unsigned_errno);
#undef CHECK
    return 1;
}

static int vector_set(const struct vector *rows, size_t count, wchar_t *pages, size_t page_size)
{
    for (size_t i = 0; i < count; ++i) {
        const struct vector *vector = &rows[i];
        if (!pages) {
            if (!verify(vector, vector->text))
                return (int)i + 1;
            continue;
        }
        size_t length = 0;
        while (vector->text[length])
            ++length;
        size_t size = (length + 1) * sizeof(wchar_t);
        for (int right = 0; right < 2; ++right) {
            wchar_t *edge = right ? (wchar_t *)((char *)pages + page_size - size) : pages;
            if (__al_syscall(10, (long)pages, page_size, 3, 0, 0, 0))
                return -1;
            memcpy(edge, vector->text, size);
            if (__al_syscall(10, (long)pages, page_size, 1, 0, 0, 0))
                return -1;
            if (!verify(vector, edge))
                return (int)i + 1;
        }
    }
    return 0;
}

static void access_fault(int signal)
{
    (void)signal;
    static const char message[] = "FAIL guard reference:wide-integer-scanner: access fault\n";
    (void)write(STDERR_FILENO, message, sizeof message - 1);
    _exit(1);
}

int main(int argc, char **argv)
{
    if (argc != 2 || (strcmp(argv[1], "unit") && strcmp(argv[1], "guard")))
        return 2;
    const char *mode = argv[1];
    int guarded = !strcmp(mode, "guard");
    wchar_t *pages = NULL;
    long raw = 0;
    size_t page_size = 0;
    if (guarded) {
        enum { SYS_MMAP = 9, SYS_MPROTECT = 10, AT_PAGESZ = 6 };
        struct sigaction action = {.sa_handler = access_fault};
        if (sigemptyset(&action.sa_mask) || sigaction(SIGSEGV, &action, NULL) ||
            sigaction(SIGBUS, &action, NULL))
            return 2;
        for (const struct aux_entry *entry = __al_auxv; entry->type; ++entry) {
            if (entry->type == AT_PAGESZ)
                page_size = entry->value;
        }
        if (page_size < 1024)
            return 2;
        raw = __al_syscall(SYS_MMAP, 0, 3 * page_size, 0, 0x22, -1, 0);
        if (raw < 0 || __al_syscall(SYS_MPROTECT, raw + page_size, page_size, 3, 0, 0, 0))
            return 2;
        pages = (void *)(raw + page_size);
    }
    if (!setlocale(LC_CTYPE, "C"))
        return 2;
    int status = vector_set(c_locale, sizeof c_locale / sizeof c_locale[0], pages, page_size);
    if (status < 0)
        return 2;
    if (status) {
        (void)fprintf(stderr, "FAIL %s reference:wide-integer-scanner: C case %d\n", mode, status);
        return 1;
    }
    if (!setlocale(LC_CTYPE, "C.UTF-8"))
        return 2;
    status = vector_set(utf8_locale, sizeof utf8_locale / sizeof utf8_locale[0], pages, page_size);
    if (status < 0)
        return 2;
    if (status) {
        (void)fprintf(stderr, "FAIL %s reference:wide-integer-scanner: UTF-8 case %d\n", mode, status);
        return 1;
    }
    if (guarded && __al_syscall(11, raw, 3 * page_size, 0, 0, 0, 0))
        return 2;
    (void)printf("PASS %s reference:wide-integer-scanner\n", mode);
    return 0;
}
