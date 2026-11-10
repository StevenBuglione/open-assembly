#define _GNU_SOURCE
#include <errno.h>
#include <locale.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <wctype.h>

static const struct classifier {
    const char *property, *name;
    int (*test)(wint_t);
    wint_t member;
} classes[] = {
    {"alnum", "iswalnum", iswalnum, '0'},
    {"alpha", "iswalpha", iswalpha, 'A'},
    {"blank", "iswblank", iswblank, '\t'},
    {"cntrl", "iswcntrl", iswcntrl, '\n'},
    {"digit", "iswdigit", iswdigit, '9'},
    {"graph", "iswgraph", iswgraph, '@'},
    {"lower", "iswlower", iswlower, 'a'},
    {"print", "iswprint", iswprint, ' '},
    {"punct", "iswpunct", iswpunct, '.'},
    {"space", "iswspace", iswspace, '\r'},
    {"upper", "iswupper", iswupper, 'Z'},
    {"xdigit", "iswxdigit", iswxdigit, 'F'},
};

enum { CLASSES = sizeof classes / sizeof classes[0], BATCH = 512 };
struct packet {
    uint32_t value;
    uint16_t mask, reserved;
    uint32_t lower, upper;
};
_Static_assert(sizeof(struct packet) == 16, "oracle packet layout");

static int direct(const char *name)
{
    errno = EDOM;
    for (unsigned i = 0; i < CLASSES; ++i) {
        if (strcmp(name, classes[i].name) == 0)
            return !(classes[i].test(classes[i].member) && errno == EDOM);
    }
    int passed = 0;
    if (strcmp(name, "towlower") == 0)
        passed = towlower(L'A') == L'a';
    else if (strcmp(name, "towupper") == 0)
        passed = towupper(L'a') == L'A';
    else if (strcmp(name, "wctype") == 0)
        passed = wctype("alpha") != 0;
    else if (strcmp(name, "iswctype") == 0)
        passed = iswctype(L'A', wctype("alpha")) != 0;
    else if (strcmp(name, "wctrans") == 0)
        passed = wctrans("tolower") != 0;
    else if (strcmp(name, "towctrans") == 0)
        passed = towctrans(L'A', wctrans("tolower")) == L'a';
    else
        return 90;
    return !(passed && errno == EDOM);
}

static int domain(const char *locale, int allow_ucd_differences)
{
    if (!setlocale(LC_CTYPE, locale))
        return 91;
    errno = EDOM;
    wctype_t descriptors[CLASSES];
    for (unsigned i = 0; i < CLASSES; ++i) {
        descriptors[i] = wctype(classes[i].property);
        if (!descriptors[i])
            return 92;
    }
    wctrans_t to_lower = wctrans("tolower"), to_upper = wctrans("toupper");
    if (!to_lower || !to_upper || wctype("Alpha") || wctype("unsupported") ||
        wctrans("TOLOWER") || wctrans("unsupported") || errno != EDOM)
        return 93;
#ifndef OA_PHASE9_HOST
    if (iswctype(L'A', (wctype_t)0) || towctrans(L'A', (wctrans_t)0) != L'A' || errno != EDOM)
        return 94;
#endif
    unsigned long rows = 0, different[CLASSES] = {0}, low_count = 0, high_count = 0;
    unsigned long inconsistent = 0, changed_errno = 0, witnesses = 0;
    struct packet data[BATCH];
    for (;;) {
        size_t bytes = fread(data, 1, sizeof data, stdin);
        if (bytes % sizeof data[0] || ferror(stdin))
            return 95;
        if (!bytes)
            break;
        size_t count = bytes / sizeof data[0];
        for (size_t index = 0; index < count; ++index) {
            const struct packet *row = &data[index];
            if (row->reserved || row->mask >> CLASSES)
                return 96;
            wint_t value = (wint_t)row->value;
            unsigned mask = 0, descriptor_mask = 0;
            errno = EDOM;
            for (unsigned bit = 0; bit < CLASSES; ++bit) {
                unsigned got = classes[bit].test(value) != 0;
                mask |= got << bit;
                descriptor_mask |= (unsigned)(iswctype(value, descriptors[bit]) != 0) << bit;
                different[bit] += got != ((row->mask >> bit) & 1u);
            }
            wint_t low = towlower(value), high = towupper(value);
            wint_t descriptor_low = towctrans(value, to_lower), descriptor_high = towctrans(value, to_upper);
            int error = errno != EDOM;
            int descriptor_error = mask != descriptor_mask || low != descriptor_low || high != descriptor_high;
            changed_errno += (unsigned)error;
            inconsistent += (unsigned)descriptor_error;
            low_count += low != row->lower;
            high_count += high != row->upper;
            if ((mask != row->mask || low != row->lower || high != row->upper || error || descriptor_error) &&
                witnesses++ < 6) {
                fprintf(stderr, "%08x classes %03x/%03x descriptor %03x lower %08x/%08x upper %08x/%08x\n",
                        row->value, mask, (unsigned)row->mask, descriptor_mask, (unsigned)low, row->lower,
                        (unsigned)high, row->upper);
            }
            ++rows;
        }
    }
    if (!rows)
        return 97;
    printf("%lu %lu %lu %lu %lu", rows, low_count, high_count, inconsistent, changed_errno);
    for (unsigned i = 0; i < CLASSES; ++i)
        printf(" %lu", different[i]);
    printf("\n");
    return inconsistent || changed_errno || (!allow_ucd_differences && witnesses) ? 33 : 0;
}

int main(int argc, char **argv)
{
    if (argc == 3 && strcmp(argv[1], "direct") == 0)
        return direct(argv[2]);
    if (argc == 2)
        return domain(argv[1], 0);
#ifdef OA_PHASE9_HOST
    if (argc == 3 && strcmp(argv[2], "compare") == 0)
        return domain(argv[1], 1);
#endif
    return 90;
}
