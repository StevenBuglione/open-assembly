#define _GNU_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#ifdef OA_PHASE10_HOST
#include <sys/mman.h>
#else
extern long __al_syscall(long, long, long, long, long, long, long);
struct aux_entry { unsigned long type, value; };
extern const struct aux_entry *const __al_auxv;
#endif

static uint32_t state = UINT32_C(0x7d4b19ac);

static uint32_t random_word(void)
{
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;
    return state;
}

static int byte_order(const char *mode)
{
    int wide = !strcmp(mode, "htonl") || !strcmp(mode, "ntohl");
    int incoming = mode[0] == 'n';
    errno = EDOM;
    if (!wide) {
        for (unsigned value = 0; value < 65536; ++value) {
            uint16_t expected = (uint16_t)((value % 256) * 256 + value / 256);
            uint16_t got = incoming ? ntohs((uint16_t)value) : htons((uint16_t)value);
            if (got != expected || errno != EDOM)
                return 10;
        }
        return 0;
    }
    for (unsigned i = 0; i < 8192; ++i) {
        uint32_t value = i ? random_word() : UINT32_C(0x0102feff);
        uint32_t expected = 0, remaining = value;
        for (unsigned j = 0; j < 4; ++j) {
            expected = expected * 256 + remaining % 256;
            remaining /= 256;
        }
        uint32_t got = incoming ? ntohl(value) : htonl(value);
        if (got != expected || errno != EDOM)
            return 10;
    }
    return 0;
}

enum { GUARDS = 2 };
static size_t page_size;
static unsigned char *data[GUARDS];

static int open_pages(void)
{
#ifdef OA_PHASE10_HOST
    long size = sysconf(_SC_PAGESIZE);
    if (size < 1024)
        return 0;
    page_size = (size_t)size;
#else
    for (const struct aux_entry *entry = __al_auxv; entry->type; ++entry) {
        if (entry->type == 6)  /* AT_PAGESZ */
            page_size = entry->value;
    }
    if (page_size < 1024)
        return 0;
#endif
    for (int i = 0; i < GUARDS; ++i) {
#ifdef OA_PHASE10_HOST
        unsigned char *base = mmap(NULL, 3 * page_size, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (base == MAP_FAILED || mprotect(base + page_size, page_size, PROT_READ | PROT_WRITE))
            return 0;
#else
        long mapping = __al_syscall(9, 0, 3 * page_size, 0, 0x22, -1, 0);
        if (mapping < 0 || __al_syscall(10, mapping + page_size, page_size, 3, 0, 0, 0))
            return 0;
        unsigned char *base = (void *)mapping;
#endif
        data[i] = base + page_size;
    }
    return 1;
}

static int close_pages(void)
{
    for (int i = 0; i < GUARDS; ++i) {
#ifdef OA_PHASE10_HOST
        if (munmap(data[i] - page_size, 3 * page_size))
#else
        if (__al_syscall(11, (long)(data[i] - page_size), 3 * page_size, 0, 0, 0, 0))
#endif
            return 0;
    }
    return 1;
}

static unsigned char *edge(int page, size_t size, int right)
{
    return data[page] + (right ? page_size - size : 0);
}

static int pristine(const unsigned char *bytes, size_t size)
{
    for (size_t i = 0; i < size; ++i) {
        if (bytes[i] != 0xa5)
            return 0;
    }
    return 1;
}

struct vector {
    int family;
    const char *spelling, *canonical;
    unsigned char bytes[16];
};

static const struct vector vectors[] = {
    {AF_INET, "0.0.0.0", "0.0.0.0", {0, 0, 0, 0}},
    {AF_INET, "255.16.192.1", "255.16.192.1", {255, 16, 192, 1}},
    {AF_INET, "127.0.0.1", "127.0.0.1", {127, 0, 0, 1}},
    {AF_INET6, "::", "::", {0}},
    {AF_INET6, "0:0:0:0:0:0:0:1", "::1", {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1}},
    {AF_INET6, "2001:0DB8:0000:0000:002A:0000:0000:0001", "2001:db8::2a:0:0:1",
     {0x20, 1, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0x2a, 0, 0, 0, 0, 0, 1}},
    {AF_INET6, "2001:DB8:0:1:2:3:4:5", "2001:db8:0:1:2:3:4:5",
     {0x20, 1, 0x0d, 0xb8, 0, 0, 0, 1, 0, 2, 0, 3, 0, 4, 0, 5}},
    {AF_INET6, "::FFFF:192.0.2.1", "::ffff:192.0.2.1",
     {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 192, 0, 2, 1}},
    {AF_INET6, "2001:db8::192.0.2.1", "2001:db8::c000:201",
     {0x20, 1, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 192, 0, 2, 1}},
};

static int parse_text(int family, const char *text, const unsigned char *expected, int right)
{
    size_t length = strlen(text) + 1;
    size_t width = family == AF_INET ? 4 : 16;
    char *input = (char *)edge(0, length, right);
    unsigned char *output = edge(1, width, right);
    memcpy(input, text, length);
    memset(data[1], 0xa5, page_size);
    errno = EDOM;
    int got = inet_pton(family, input, output);
    if (memcmp(input, text, length) || errno != EDOM ||
        (right ? output[-1] : output[width]) != 0xa5)
        return 0;
#ifndef OA_PHASE10_HOST
    if (!expected && !pristine(output, width))
        return 0;
#endif
    return expected ? got == 1 && !memcmp(output, expected, width) : got == 0;
}

static int render(int family, const unsigned char *bytes, const char *expected, int right)
{
    size_t width = family == AF_INET ? 4 : 16;
    size_t length = strlen(expected) + 1;
    unsigned char *input = edge(0, width, right);
    char *output = (char *)edge(1, length, right);
    memcpy(input, bytes, width);
    memset(data[1], 0xa5, page_size);
    errno = EDOM;
    const char *result = inet_ntop(family, input, output, (socklen_t)length);
    if (result != output || memcmp(output, expected, length) || memcmp(input, bytes, width) ||
        errno != EDOM || (unsigned char)(right ? output[-1] : output[length]) != 0xa5)
        return 0;
    memset(output, 0xa5, length);
    errno = EDOM;
    if (inet_ntop(family, input, output, (socklen_t)(length - 1)) || errno != ENOSPC)
        return 0;
#ifndef OA_PHASE10_HOST
    if (!pristine((const unsigned char *)output, length))
        return 0;
#endif
    return 1;
}

static int model_text(int family, const unsigned char *bytes, char output[46])
{
    if (family == AF_INET)
        return snprintf(output, 46, "%u.%u.%u.%u", bytes[0], bytes[1], bytes[2], bytes[3]) > 0;
    unsigned words[8];
    for (size_t i = 0; i < 8; ++i)
        words[i] = 256u * bytes[2 * i] + bytes[2 * i + 1];
    if (!(words[0] || words[1] || words[2] || words[3] || words[4]) && words[5] == 65535)
        return snprintf(output, 46, "::ffff:%u.%u.%u.%u",
                        bytes[12], bytes[13], bytes[14], bytes[15]) > 0;
    size_t best = 8, extent = 1;
    for (size_t i = 0; i < 8;) {
        if (words[i]) {
            ++i;
            continue;
        }
        size_t begin = i;
        while (i < 8 && !words[i])
            ++i;
        if (i - begin > extent) {
            best = begin;
            extent = i - begin;
        }
    }
    size_t written = 0;
    for (size_t i = 0; i < 8;) {
        if (i == best) {
            output[written++] = ':';
            output[written++] = ':';
            i += extent;
            continue;
        }
        if (written && output[written - 1] != ':')
            output[written++] = ':';
        int part = snprintf(output + written, 46 - written, "%x", words[i++]);
        if (part <= 0 || (size_t)part >= 46 - written)
            return 0;
        written += (size_t)part;
    }
    output[written] = '\0';
    return 1;
}

static int sample(int parse, int right)
{
    int family = random_word() % 4 ? AF_INET6 : AF_INET;
    unsigned char bytes[16];
    for (size_t i = 0; i < sizeof bytes; i += 2) {
        uint32_t word = random_word();
        if (word & 4) {
            bytes[i] = 0;
            bytes[i + 1] = 0;
        } else {
            bytes[i] = (unsigned char)(word >> 16);
            bytes[i + 1] = (unsigned char)(word >> 24);
        }
    }
    if (family == AF_INET6 && (random_word() & 15) == 0) {
        memset(bytes, 0, 10);
        bytes[10] = bytes[11] = 255;
    } else if (family == AF_INET6 && !parse) {
        static const unsigned char compatible_prefix[12] = {0};
        if (!memcmp(bytes, compatible_prefix, sizeof compatible_prefix))
            bytes[0] = 0x20;  /* The separate policy case covers compatible rendering. */
    }
    char text[46];
    if (!model_text(family, bytes, text))
        return 0;
    if (!parse)
        return render(family, bytes, text, right);
    if (family == AF_INET6 && (random_word() & 1)) {
        unsigned words[8];
        for (size_t i = 0; i < 8; ++i)
            words[i] = 256u * bytes[2 * i] + bytes[2 * i + 1];
        if (snprintf(text, sizeof text, "%04X:%04X:%04X:%04X:%04X:%04X:%04X:%04X",
                     words[0], words[1], words[2], words[3], words[4], words[5], words[6], words[7]) != 39)
            return 0;
    }
    return parse_text(family, text, bytes, right);
}

static int invalid(int right)
{
    static const char *const v4[] = {
        "", "1.2.3", "1.2.3.4.5", "1..3.4", "1.2.3.4.", "256.2.3.4",
        "01.2.3.4", "1.2.003.4", "+1.2.3.4", " 1.2.3.4", "1.2.3.4 ",
        "0x1.2.3.4", "1.2.3.\xff", "1.2.3.4294967296",
    };
    static const char *const v6[] = {
        "", ":", ":::", "1::2::3", "12345::", "::g", "1:2:3:4:5:6:7",
        "1:2:3:4:5:6:7:8:9", "1:2:3:4:5:6:7:8::", "1:2:3:4:5:6:7:8:",
        "::ffff:01.2.3.4", "::ffff:256.2.3.4", "::ffff:1.2.3", "1:2:3:4:5:6:7:1.2.3.4",
        "::1%lo", "[::1]", " ::1", "::1 ", "::1\xff",
    };
    for (size_t i = 0; i < sizeof v4 / sizeof v4[0]; ++i) {
        if (!parse_text(AF_INET, v4[i], NULL, right))
            return 0;
    }
    for (size_t i = 0; i < sizeof v6 / sizeof v6[0]; ++i) {
        if (!parse_text(AF_INET6, v6[i], NULL, right))
            return 0;
    }
    return 1;
}

static int codecs(int parse)
{
    if (!open_pages())
        return 90;
    for (int right = 0; right < 2; ++right) {
        for (size_t i = 0; i < sizeof vectors / sizeof vectors[0]; ++i) {
            const struct vector *item = &vectors[i];
            if (parse ? !parse_text(item->family, item->spelling, item->bytes, right)
                      : !render(item->family, item->bytes, item->canonical, right))
                return 11;
        }
        unsigned char output[16];
        memset(output, 0xa5, sizeof output);
        errno = EDOM;
        if (parse) {
            if (!invalid(right) || inet_pton(AF_UNSPEC, "127.0.0.1", output) != -1 ||
                errno != EAFNOSUPPORT || !pristine(output, sizeof output))
                return 12;
        } else if (inet_ntop(AF_UNSPEC, vectors[0].bytes, (char *)output, sizeof output) ||
                   errno != EAFNOSUPPORT || !pristine(output, sizeof output)) {
            return 12;
        }
        for (unsigned i = 0; i < 2048; ++i) {
            if (!sample(parse, right))
                return 13;
        }
    }
    return close_pages() ? 0 : 90;
}

static int compatible(void)
{
    const unsigned char bytes[16] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 192, 0, 2, 1};
    if (!open_pages())
        return 90;
    if (!parse_text(AF_INET6, "::192.0.2.1", bytes, 1) || !render(AF_INET6, bytes, "::c000:201", 1))
        return 20;
    return close_pages() ? 0 : 90;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "pton") || !strcmp(argv[1], "ntop"))
        return codecs(!strcmp(argv[1], "pton"));
    if (!strcmp(argv[1], "compatible"))
        return compatible();
    return byte_order(argv[1]);
}
