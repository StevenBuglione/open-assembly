#include <errno.h>
#include <json.h>
#include <limits.h>
#include <signal.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

enum { END, STRING, NUMBER, TRUE, FALSE, NULL_VALUE, OPEN_OBJECT, CLOSE_OBJECT,
       OPEN_ARRAY, CLOSE_ARRAY, COLON, COMMA };

static const size_t canary = UINT64_C(0x8de1ea30ab5f4307);
static const unsigned char *text(const char *input)
{
    return (const unsigned char *)input;
}

static int hex_digit(unsigned byte)
{
    return (byte >= '0' && byte <= '9') || (byte >= 'a' && byte <= 'f') ||
           (byte >= 'A' && byte <= 'F');
}

static int ascii_string_boundaries(void)
{
    unsigned char raw[] = {'"', 'x', '"'};
    unsigned char escape[] = {'"', '\\', 'x', '"'};
    unsigned char hex[] = {'"', '\\', 'u', '0', '0', '0', '0', '"'};
    for (unsigned byte = 0; byte < 256; ++byte) {
        raw[1] = escape[2] = (unsigned char)byte;
        long expected = byte == '"' ? 2 : byte >= 0x20 && byte < 0x80 && byte != '\\' ? 3 : -EILSEQ;
        if (json_scan_string(raw, sizeof raw, 0) != expected)
            return 16;
        expected = byte && strchr("\"\\/bfnrt", (int)byte) ? 4 : -EILSEQ;
        if (json_scan_string(escape, sizeof escape, 0) != expected)
            return 17;
        for (size_t digit = 3; digit < 7; ++digit) {
            hex[digit] = (unsigned char)byte;
            expected = hex_digit(byte) ? (long)sizeof hex : -EILSEQ;
            if (json_scan_string(hex, sizeof hex, 0) != expected)
                return 18;
            hex[digit] = '0';
        }
    }
    return 0;
}

static int scalar_bytes(const unsigned char *bytes, size_t width)
{
    unsigned lead = bytes[0];
    if (width == 2 && (lead < 0xc2 || lead > 0xdf))
        return 0;
    if (width == 3 && (lead < 0xe0 || lead > 0xef))
        return 0;
    if (width == 4 && (lead < 0xf0 || lead > 0xf4))
        return 0;
    for (size_t i = 1; i < width; ++i)
        if (bytes[i] < 0x80 || bytes[i] > 0xbf)
            return 0;
    return !((lead == 0xe0 && bytes[1] < 0xa0) || (lead == 0xed && bytes[1] > 0x9f) ||
             (lead == 0xf0 && bytes[1] < 0x90) || (lead == 0xf4 && bytes[1] > 0x8f));
}

static int utf8_string_boundaries(void)
{
    static const unsigned char vectors[][4] = {
        {0xc2, 0x80}, {0xdf, 0xbf}, {0xe0, 0xa0, 0x80}, {0xe1, 0x80, 0x80},
        {0xed, 0x9f, 0xbf}, {0xef, 0xbf, 0xbf}, {0xf0, 0x90, 0x80, 0x80},
        {0xf1, 0x80, 0x80, 0x80}, {0xf4, 0x8f, 0xbf, 0xbf}
    };
    for (size_t i = 0; i < sizeof vectors / sizeof *vectors; ++i) {
        size_t width = i < 2 ? 2 : i < 6 ? 3 : 4;
        unsigned char input[6] = {'"'};
        memcpy(input + 1, vectors[i], width);
        input[width + 1] = '"';
        for (size_t pos = 0; pos < width; ++pos) {
            for (unsigned byte = 0x80; byte < 256; ++byte) {
                input[pos + 1] = (unsigned char)byte;
                long expected = scalar_bytes(input + 1, width) ? (long)width + 2 : -EILSEQ;
                if (json_scan_string(input, width + 2, 0) != expected)
                    return 19;
            }
            input[pos + 1] = vectors[i][pos];
        }
        for (size_t length = 0; length < width + 2; ++length)
            if (json_scan_string(input, length, 0) != -EILSEQ)
                return 20;
    }
    return 0;
}

static int number_boundaries(void)
{
    unsigned char integer[] = {'1', '0'};
    unsigned char fraction[] = {'1', '.', '0'};
    unsigned char exponent[] = {'1', 'e', '0'};
    unsigned char zero[] = {'0', '0'};
    unsigned char after_fraction[] = {'1', '.', '0', '0'};
    unsigned char after_exponent[] = {'1', 'e', '0', '0'};
    for (unsigned byte = 0; byte < 256; ++byte) {
        int digit = byte >= '0' && byte <= '9';
        integer[1] = fraction[2] = exponent[2] = (unsigned char)byte;
        long end = digit ? 2 : byte == '.' || byte == 'e' || byte == 'E' ? -EILSEQ : 1;
        if (json_scan_number(integer, sizeof integer, 0) != end ||
            json_scan_number(fraction, sizeof fraction, 0) != (digit ? 3 : -EILSEQ) ||
            json_scan_number(exponent, sizeof exponent, 0) != (digit ? 3 : -EILSEQ))
            return 15;
        zero[1] = after_fraction[3] = after_exponent[3] = (unsigned char)byte;
        long fraction_end = digit ? 4 : byte == 'e' || byte == 'E' ? -EILSEQ : 3;
        if (json_scan_number(zero, sizeof zero, 0) != (digit || end < 0 ? -EILSEQ : 1) ||
            json_scan_number(after_fraction, sizeof after_fraction, 0) != fraction_end ||
            json_scan_number(after_exponent, sizeof after_exponent, 0) != (digit ? 4 : 3))
            return 16;
    }
    return 0;
}

static int lexer_boundaries(void)
{
    size_t result[] = {canary, canary, canary};
    static const char *const literals[] = {"true", "false", "null"};
    for (size_t i = 0; i < sizeof literals / sizeof *literals; ++i) {
        size_t length = strlen(literals[i]);
        unsigned char input[6];
        memcpy(input, literals[i], length);
        for (size_t cut = 1; cut < length; ++cut)
            if (json_lex(input, cut, 0, result) != -EILSEQ ||
                result[0] != canary || result[1] != canary || result[2] != canary)
                return 16;
        for (size_t pos = 1; pos < length; ++pos) {
            for (unsigned byte = 0; byte < 256; ++byte) {
                if (byte == (unsigned char)literals[i][pos])
                    continue;
                input[pos] = (unsigned char)byte;
                if (json_lex(input, length, 0, result) != -EILSEQ ||
                    result[0] != canary || result[1] != canary || result[2] != canary)
                    return 19;
            }
            input[pos] = (unsigned char)literals[i][pos];
        }
        for (unsigned byte = 0; byte < 256; ++byte) {
            input[length] = (unsigned char)byte;
            if (json_lex(input, length + 1, 0, result) || result[0] != TRUE + i ||
                result[1] || result[2] != length)
                return 17;
        }
        result[0] = result[1] = result[2] = canary;
    }
    for (size_t length = 1; length <= 4; ++length)
        if (json_lex(text("\t\r\n "), length, length, result) || result[0] ||
            result[1] != length || result[2] != length)
            return 18;
    if (json_lex(text("x\n:"), 3, 1, result) || result[0] != COLON ||
        result[1] != 2 || result[2] != 3)
        return 20;
    for (unsigned value = 0; value < 256; ++value) {
        unsigned char byte = (unsigned char)value;
        const char *punctuation = "{}[]:,";
        const char *at = byte ? strchr(punctuation, byte) : NULL;
        long kind = at ? OPEN_OBJECT + (long)(at - punctuation) :
                    byte >= '0' && byte <= '9' ? NUMBER :
                    byte && strchr(" \t\r\n", byte) ? END : -1;
        result[0] = result[1] = result[2] = canary;
        int status = json_lex(&byte, 1, 0, result);
        if (kind >= 0) {
            if (status || result[0] != (size_t)kind || result[1] != (kind == END) || result[2] != 1)
                return 21;
        } else if (status != -EILSEQ || result[0] != canary ||
                   result[1] != canary || result[2] != canary) {
            return 21;
        }
    }
    return 0;
}

static int scan_string(void)
{
    errno = EDOM;
    if (json_scan_string(text("!\"a\"tail"), 8, 1) != 4 || errno != EDOM)
        return 11;
    const char *valid[] = {
        "\"\"", "\"plain ASCII /\"", "\"\\\"\\\\\\/\\b\\f\\n\\r\\t\"",
        "\"\\u0000\\u0061\\uABcd\\ud7ff\\ue000\"",
        "\"\\ud800\\udc00\\uDBFF\\uDFFF\"",
        "\"\xc2\x80\xdf\xbf\xe0\xa0\x80\xed\x9f\xbf\xee\x80\x80"
        "\xf0\x90\x80\x80\xf4\x8f\xbf\xbf\""
    };
    for (size_t i = 0; i < sizeof valid / sizeof *valid; ++i)
        if (json_scan_string(text(valid[i]), strlen(valid[i]), 0) != (long)strlen(valid[i]) ||
            errno != EDOM)
            return 12;
    const char *bad[] = {
        "x", " \"x\"", "\"", "\"x", "\"\\", "\"\\v\"", "\"\\U0061\"", "\"\\u123\"",
        "\"\\u123X\"", "\"\\ug000\"", "\"\\udc00\"", "\"\\ud800\"", "\"\\ud800a\"",
        "\"\\ud800\\xDC00\"", "\"\\ud800\\u0020\"", "\"\\ud800\\udbff\"",
        "\"\\uDFFF\"", "\"\\uDC00\\uDC00\"", "\"\\uD800\\uE000\"",
        "\"\x1f\"", "\"\x80\"", "\"\xbf\"", "\"\xc0\xaf\"", "\"\xc1\xbf\"",
        "\"\xc2\x7f\"", "\"\xc2\xc0\"", "\"\xe0\x9f\xbf\"", "\"\xed\xa0\x80\"",
        "\"\xe1\x80\"", "\"\xe1\x80\xc0\"", "\"\xf0\x8f\xbf\xbf\"",
        "\"\xf1\x80\x80\"", "\"\xf1\x80\x80\xc0\"", "\"\xf4\x90\x80\x80\"",
        "\"\xf5\x80\x80\x80\"", "\"\xff\""
    };
    for (size_t i = 0; i < sizeof bad / sizeof *bad; ++i)
        if (json_scan_string(text(bad[i]), strlen(bad[i]), 0) != -EILSEQ || errno != EDOM)
            return 13;
    const unsigned char zero[] = {'"', 0, '"'};
    if (json_scan_string(zero, sizeof zero, 0) != -EILSEQ ||
        json_scan_string(text("\"\""), 1, 0) != -EILSEQ ||
        json_scan_string(NULL, 0, 0) != -EILSEQ)
        return 14;
    if (json_scan_string(NULL, 1, 0) != -EINVAL ||
        json_scan_string(text(""), 0, 1) != -EINVAL ||
        json_scan_string(text(""), (size_t)LONG_MAX + 1, 0) != -EOVERFLOW ||
        json_scan_string((void *)(uintptr_t)(SIZE_MAX - 3), 4, 0) != -EOVERFLOW || errno != EDOM)
        return 15;
    const unsigned char short_escape[] = {'"', '\\', 'u', '1', '2', '3'};
    const unsigned char short_pair[] = {'"', '\\', 'u', 'D', '8', '0', '0', '\\', 'u', 'D', 'C', '0'};
    for (size_t i = 0; i < 4; ++i)
        if (json_scan_string(short_escape, 3 + i, 0) != -EILSEQ ||
            json_scan_string(short_pair, 9 + i, 0) != -EILSEQ || errno != EDOM)
            return 21;
    int status = ascii_string_boundaries();
    return status ? status : utf8_string_boundaries();
}

static int scan_number(void)
{
    errno = EDOM;
    if (json_scan_number(text("xx-7.05E+99)"), 12, 2) != 11 || errno != EDOM)
        return 11;
    const struct { const char *input; long end; } valid[] = {
        {"0", 1}, {"-0", 2}, {"1", 1}, {"9", 1}, {"10", 2}, {"-999999999999999999999999", 25},
        {"0.00", 4}, {"0e0", 3}, {"7e-0", 4}, {"7E+2", 4}, {"1.2.3", 3}, {"1e1e2", 3},
        {"20 ", 2}, {"2[", 1}, {"5a", 1}, {"5/", 1}, {"5:", 1}, {"5\xc2\xa0", 1}
    };
    for (size_t i = 0; i < sizeof valid / sizeof *valid; ++i)
        if (json_scan_number(text(valid[i].input), strlen(valid[i].input), 0) != valid[i].end ||
            errno != EDOM)
            return 12;
    const char *bad[] = {"", "-", "--1", "+1", ".1", " 0", "01", "-01", "0.",
                         "0.e1", "0e", "0e+", "0e-", "0e--1", "0e:0", "9./",
                         "0e+x", "\xff", "/", ":"};
    for (size_t i = 0; i < sizeof bad / sizeof *bad; ++i)
        if (json_scan_number(text(bad[i]), strlen(bad[i]), 0) != -EILSEQ || errno != EDOM)
            return 13;
    if (json_scan_number(NULL, 0, 0) != -EILSEQ || json_scan_number(NULL, 1, 0) != -EINVAL ||
        json_scan_number(text("0"), 1, 2) != -EINVAL ||
        json_scan_number(text("0"), (size_t)LONG_MAX + 1, 0) != -EOVERFLOW ||
        json_scan_number((void *)(uintptr_t)(SIZE_MAX - 3), 4, 0) != -EOVERFLOW || errno != EDOM)
        return 14;
    return number_boundaries();
}

static int lexer(void)
{
    size_t output[4] = {canary, canary, canary, canary};
    errno = EDOM;
    if (json_lex(text("!\t\r trueX"), 9, 1, output) || output[0] != TRUE ||
        output[1] != 4 || output[2] != 8 || output[3] != canary || errno != EDOM)
        return 11;
    const char *tokens[] = {" ", "\"X\"", "-0", "trueX", "falseX", "nullX",
                            "{", "}", "[", "]", ":", ","};
    const size_t start[] = {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    const size_t end[] = {1, 3, 2, 4, 5, 4, 1, 1, 1, 1, 1, 1};
    for (size_t i = 0; i < sizeof tokens / sizeof *tokens; ++i)
        if (json_lex(text(tokens[i]), strlen(tokens[i]), 0, output) ||
            output[0] != i || output[1] != start[i] || output[2] != end[i] || output[3] != canary)
            return 12;
    const char *bad[] = {"\v", "\f", "\xc2\xa0", "\xef\xbb\xbf", "True", "tr", "truE",
                         "f", "falsE", "nul", "nuLl", "+1", "01", "\"\\v\"", ";", "!"};
    const size_t previous[] = {COMMA, 0, 1, canary};
    for (size_t i = 0; i < sizeof bad / sizeof *bad; ++i)
        if (json_lex(text(bad[i]), strlen(bad[i]), 0, output) != -EILSEQ ||
            memcmp(output, previous, sizeof output) || errno != EDOM)
            return 13;
    if (json_lex(NULL, 0, 0, output) || output[0] || output[1] || output[2] || output[3] != canary)
        return 14;
    const size_t empty[] = {0, 0, 0, canary};
    if (json_lex(NULL, 1, 0, output) != -EINVAL || json_lex(text(""), 0, 1, output) != -EINVAL ||
        json_lex(text(""), 0, 0, NULL) != -EINVAL ||
        json_lex(text(""), (size_t)LONG_MAX + 1, 0, output) != -EOVERFLOW ||
        json_lex((void *)(uintptr_t)(SIZE_MAX - 3), 4, 0, output) != -EOVERFLOW ||
        json_lex(text(""), 0, 0, (void *)(uintptr_t)(SIZE_MAX - 15)) != -EOVERFLOW ||
        memcmp(output, empty, sizeof output) || errno != EDOM)
        return 15;
    return lexer_boundaries();
}

static int untouched(const size_t *words, size_t count)
{
    for (size_t i = 0; i < count; ++i)
        if (words[i] != canary)
            return 0;
    return 1;
}

static volatile sig_atomic_t parsing;

static void reject_memory_fault(int signal)
{
    (void)signal;
    _exit(parsing ? 29 : 93);
}

static long guarded_parse(const unsigned char *data, size_t length, size_t *workspace,
                          size_t frames, size_t *tokens, size_t capacity)
{
    parsing = 1;
    long result = json_parse(data, length, workspace, frames, tokens, capacity);
    parsing = 0;
    return result;
}

static int parser(void)
{
    struct sigaction handler = {0};
    handler.sa_handler = reject_memory_fault;
    if (sigemptyset(&handler.sa_mask) || sigaction(SIGSEGV, &handler, NULL) ||
        sigaction(SIGBUS, &handler, NULL))
        return 92;
    size_t work[19], output[9 * 4];
    for (size_t i = 0; i < sizeof output / sizeof *output; ++i)
        output[i] = canary;
    const char input[] = " {\"x\":[true,{},-0],\"x\":false} ";
    const size_t expected[][4] = {
        {OPEN_OBJECT, 1, 29, SIZE_MAX}, {STRING, 2, 5, 0}, {OPEN_ARRAY, 6, 18, 0},
        {TRUE, 7, 11, 2}, {OPEN_OBJECT, 12, 14, 2}, {NUMBER, 15, 17, 2},
        {STRING, 19, 22, 0}, {FALSE, 23, 28, 0}
    };
    errno = EDOM;
    if (guarded_parse(text(input), sizeof input - 1, work, 8, output, 9) != 8 ||
        memcmp(output, expected, sizeof expected) || !untouched(output + 32, 4) || errno != EDOM)
        return 11;
    const struct { const char *input; size_t kind, start, end; } scalars[] = {
        {" \t0\r\n", NUMBER, 2, 3}, {"null", NULL_VALUE, 0, 4}, {" \"x\"", STRING, 1, 4},
        {"false", FALSE, 0, 5}, {"true ", TRUE, 0, 4}
    };
    for (size_t i = 0; i < sizeof scalars / sizeof *scalars; ++i) {
        const size_t record[] = {scalars[i].kind, scalars[i].start, scalars[i].end, SIZE_MAX};
        if (guarded_parse(text(scalars[i].input), strlen(scalars[i].input), work, 0, output, 1) != 1 ||
            memcmp(output, record, sizeof record) || errno != EDOM)
            return 12;
    }
    for (size_t i = 0; i < sizeof output / sizeof *output; ++i)
        output[i] = canary;
    const char *invalid[] = {"", " ", "]", "{", "[", "[}", "{]", "[,]", "[1,]", "[1 2]",
                             "{,}", "{\"x\"}", "{\"x\" 1}", "{\"x\":}", "{\"x\":1,}",
                             "{\"x\":1 \"y\":2}", "{1:2}", "{\"x\":[1}", "null false",
                             "trueX", "01", "\xef\xbb\xbf[]", "\"\\udc00\"", "null\v"};
    for (size_t i = 0; i < sizeof invalid / sizeof *invalid; ++i)
        if (guarded_parse(text(invalid[i]), strlen(invalid[i]), work, 8, output, 9) != -EILSEQ ||
            !untouched(output, 36) || errno != EDOM)
            return 13;
    if (guarded_parse(text(input), sizeof input - 1, work, 2, output, 9) != -ENOSPC ||
        guarded_parse(text(input), sizeof input - 1, work, 8, output, 7) != -ENOSPC ||
        guarded_parse(text("[]"), 2, work, 0, output, 9) != -ENOSPC ||
        guarded_parse(text("0"), 1, work, 0, NULL, 0) != -ENOSPC ||
        guarded_parse(text("!"), 1, work, 0, NULL, 0) != -EILSEQ ||
        !untouched(output, 36) || errno != EDOM)
        return 14;
    if (guarded_parse(NULL, 0, work, 8, output, 9) != -EILSEQ ||
        guarded_parse(NULL, 1, work, 8, output, 9) != -EINVAL ||
        guarded_parse(text("!"), 1, NULL, 0, output, 9) != -EINVAL ||
        guarded_parse(text("!"), 1, work, 8, NULL, 1) != -EINVAL ||
        guarded_parse(text("!"), (size_t)LONG_MAX + 1, work, 8, output, 9) != -EOVERFLOW ||
        guarded_parse(text("!"), 1, work, SIZE_MAX, output, 9) != -EOVERFLOW ||
        guarded_parse(text("!"), 1, work, SIZE_MAX / 16, output, 9) != -EOVERFLOW ||
        guarded_parse(text("!"), 1, work, 8, output, SIZE_MAX) != -EOVERFLOW ||
        guarded_parse((void *)(uintptr_t)(SIZE_MAX - 3), 4, work, 8, output, 9) != -EOVERFLOW ||
        guarded_parse(text("!"), 1, (void *)(uintptr_t)(SIZE_MAX - 15), 0, output, 9) != -EOVERFLOW ||
        guarded_parse(text("!"), 1, work, 8, (void *)(uintptr_t)(SIZE_MAX - 15), 1) != -EOVERFLOW ||
        !untouched(output, 36) || errno != EDOM)
        return 15;
    const size_t nested[][4] = {{OPEN_ARRAY, 0, 4, SIZE_MAX}, {OPEN_ARRAY, 1, 3, 0}};
    return guarded_parse(text("[[]]"), 4, work, 2, output, 2) == 2 &&
           !memcmp(output, nested, sizeof nested) && untouched(output + 8, 28) ? 0 : 16;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "string")) return scan_string();
    if (!strcmp(argv[1], "number")) return scan_number();
    if (!strcmp(argv[1], "lex")) return lexer();
    if (!strcmp(argv[1], "parse")) return parser();
    return 91;
}
