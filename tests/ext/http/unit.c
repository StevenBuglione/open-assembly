#include <errno.h>
#include <http.h>
#include <stdint.h>
#include <string.h>

#define HEAD (1u << 16)
#define LIMIT 8192

static const unsigned char *text(const char *input)
{
    return (const unsigned char *)input;
}

static int token(void)
{
    static const char allowed[] =
        "!#$%&'*+-.^_\x60|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
    errno = EDOM;
    if (http_is_token_byte('A') != 1 || errno != EDOM)
        return 11;
    for (unsigned byte = 0; byte < 256; ++byte) {
        unsigned expected = 0;
        for (size_t i = 0; i < sizeof allowed - 1; ++i)
            expected |= byte == (unsigned char)allowed[i];
        if (http_is_token_byte((unsigned char)byte) != expected || errno != EDOM)
            return 12;
    }
    return 0;
}

static int find(void)
{
    errno = EDOM;
    if (http_find_header_end(text("x\r\n\r\nx\r\n\r\n"), 10) != 5 || errno != EDOM)
        return 11;
    if (http_find_header_end(NULL, 0) || http_find_header_end(text("\r\n\r\n"), 0) ||
        http_find_header_end(text("\r\n\r\n"), 1) || http_find_header_end(text("\r\n\r\n"), 2) ||
        http_find_header_end(text("\r\n\r\n"), 3) || http_find_header_end(text("\r\n\r\n"), 4) != 4)
        return 12;
    const unsigned char input[] = {0xff, '\r', '\r', '\n', '\r', 0, '\n', '\r', '\n', '\r', '\n'};
    if (http_find_header_end(input, sizeof input) != sizeof input ||
        http_find_header_end(input, sizeof input - 1) || errno != EDOM)
        return 13;
    unsigned char long_span[LIMIT + 9];
    memset(long_span, 'x', sizeof long_span);
    memcpy(long_span + LIMIT + 3, "\r\n\r\n", 4);
    if (http_find_header_end(long_span, sizeof long_span) != LIMIT + 7 ||
        http_find_header_end(long_span, LIMIT + 6) || errno != EDOM)
        return 14;
    return 0;
}

enum field_role { METHOD, TARGET, NAME, VALUE, HOST_NAME, PORT, CONTENT_LENGTH, VERSION };

static int tchar(unsigned byte)
{
    static const char marks[] = "!#$%&'*+-.^_\x60|~";
    return (byte >= '0' && byte <= '9') || (byte >= 'A' && byte <= 'Z') ||
           (byte >= 'a' && byte <= 'z') || (byte && strchr(marks, (int)byte));
}

static int parser_octets(void)
{
    static const struct { const char *message; enum field_role role; unsigned exact; } rows[] = {
        {"@ET / HTTP/1.0\r\n\r\n", METHOD, 'G'},
        {"G@T / HTTP/1.0\r\n\r\n", METHOD, 'E'},
        {"GE@ / HTTP/1.0\r\n\r\n", METHOD, 'T'},
        {"GET /@q HTTP/1.0\r\n\r\n", TARGET, 0},
        {"GET / HTTP/1.0\r\n@XY:z\r\n\r\n", NAME, 0},
        {"GET / HTTP/1.0\r\nX:@z\r\n\r\n", VALUE, 0},
        {"GET / HTTP/1.1\r\nHost: a@q\r\n\r\n", HOST_NAME, 0},
        {"GET / HTTP/1.1\r\nHost: a:@\r\n\r\n", PORT, 0},
        {"GET / HTTP/1.1\r\nHost: a\r\nContent-Length: 0@0\r\n\r\n", CONTENT_LENGTH, 0},
        {"GET / HTTP/1.@\r\nHost: a\r\n\r\n", VERSION, 0},
    };
    for (size_t row = 0; row < sizeof rows / sizeof *rows; ++row) {
        unsigned char input[64];
        size_t length = strlen(rows[row].message);
        size_t offset = (size_t)(strchr(rows[row].message, '@') - rows[row].message);
        memcpy(input, rows[row].message, length);
        for (unsigned byte = 0; byte < 256; ++byte) {
            int digit = byte >= '0' && byte <= '9';
            int alpha = (byte >= 'A' && byte <= 'Z') || (byte >= 'a' && byte <= 'z');
            unsigned expected;
            switch (rows[row].role) {
            case METHOD: expected = byte == rows[row].exact ? 200 : tchar(byte) ? 405 : 400; break;
            case TARGET: expected = byte >= 0x21 && byte <= 0x7e && byte != '#' ? 404 : 400; break;
            case NAME: expected = tchar(byte) ? 200 : 400; break;
            case VALUE: expected = byte == '\t' || (byte >= 0x20 && byte <= 0x7e) ? 200 : 400; break;
            case HOST_NAME: expected = digit || alpha || byte == '-' || byte == '.' ? 200 : 400; break;
            case PORT: expected = digit ? 200 : 400; break;
            case CONTENT_LENGTH: expected = byte == '0' ? 200 : 400; break;
            default: expected = byte == '0' || byte == '1' ? 200 : 400; break;
            }
            input[offset] = (unsigned char)byte;
            if (http_parse(input, length) != expected || errno != EDOM)
                return 18;
        }
    }
    return 0;
}

static int parser(void)
{
    static const char ok[] = "GET / HTTP/1.1\r\nHost: local\r\n\r\n";
    errno = EDOM;
    if (http_parse(text(ok), sizeof ok - 1) != 200 || errno != EDOM)
        return 11;
    static const struct { const char *input; unsigned expected; } rows[] = {
        {"PUT / HTTP/1.0\r\n\r\n", 405},
        {"GET / HTTP/1.0\r\nXransfer-Encoding: x\r\n\r\n", 200},
        {"GET / HTTP/1.0\r\nTransfer-Xncoding: x\r\n\r\n", 200},
        {"GET / HTTP/1.0\r\nXost: x\r\n\r\n", 200},
        {"GET / HTTP/1.0\r\nXontent-Length: x\r\n\r\n", 200},
        {"GET / HTTP/1.0\r\nContent-Xength: x\r\n\r\n", 200},
        {"GET / HTTP/1.0\r\nX: a\rb\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost: :80\r\n\r\n", 400},
        {"GET /~ HTTP/1.1\r\nHost: z9\r\n\r\n", 404},
        {"GET / HTTP/1.1\r\nHost: @\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost: {\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost: a::\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost: a:1/\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost: a:9\r\n\r\n", 200},
        {"GET / HTTP/1.1\r\nHost:a\r\nContent-Length: 0\r\n\r\n", 200},
        {"GET / HTTP/1.1\r\nHost:a\r\nContent-Length: 01\r\n\r\n", 400},
        {"HEAD / HTTP/1.1\r\nHost:x\r\n\r\n", HEAD | 200},
        {"HEAD /?q HTTP/1.0\r\n\r\n", HEAD | 404},
        {"GET /abc HTTP/1.0\r\n\r\n", 404},
        {"GET / HTTP/1.0\r\n\r\n", 200},
        {"GET / HTTP/1.1\r\n\r\n", 400},
        {"POST / HTTP/1.1\r\nHost:x\r\n\r\n", 405},
        {"head / HTTP/1.1\r\nHost:x\r\n\r\n", 405},
        {"! / HTTP/1.1\r\nHost:x\r\n\r\n", 405},
        {"GET / HTTP/1.0\r\nHost:localhost\r\n\r\n", 200},
        {"GET / HTTP/1.1\r\nHoST:\t a.B-1:65535 \t\r\nx:\r\n\r\n", 200},
        {"GET / HTTP/1.1\r\nHost:x:00000\r\n\r\n", 200},
        {"GET / HTTP/1.1\r\nHost:x:65536\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x:000000\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x:\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x:a\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x_\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:-\r\n\r\n", 200},
        {"GET / HTTP/1.1\r\nHost:0\r\n\r\n", 200},
        {"GET / HTTP/1.1\r\nHost:.\r\n\r\n", 200},
        {"GET / HTTP/1.1\r\nHost: \t\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x\r\nHOST:y\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x\r\nContent-Length:\t 000\t\r\n\r\n", 200},
        {"GET / HTTP/1.1\r\nHost:x\r\ncontent-length:1\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x\r\ncontent-length:+0\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x\r\ncontent-length:\t\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x\r\nContent-Length:0\r\nContent-Length:0\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x\r\nTransfer-Encoding:identity\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x\r\nTransfer-Encodinf:identity\r\n\r\n", 200},
        {"GET / HTTP/1.1\r\nHost:x\r\ncontent-lengti:1\r\n\r\n", 200},
        {"GET / HTTP/1.1\r\nHost:x\r\nX:\t !~\r\n\r\n", 200},
        {"GET / HTTP/1.1\r\nHost:x\r\nX:\x7f\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x\r\nX:\xff\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x\r\n X:q\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x\r\nX :q\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x\r\n:q\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x\r\nX\r\n\r\n", 400},
        {"GET / HTTP/1.1\r\nHost:x\nX:y\r\n\r\n", 400},
        {"GET / HTTP/1.1\nHost:x\n\n", 0},
        {"GET / HTTP/1.1\r\nHost:x\r\n\r\nbad\r\n\r\n", 200},
        {"GET  / HTTP/1.1\r\nHost:x\r\n\r\n", 400},
        {"GET /  HTTP/1.1\r\nHost:x\r\n\r\n", 400},
        {"GET\t/ HTTP/1.1\r\nHost:x\r\n\r\n", 400},
        {"GE@ / HTTP/1.0\r\n\r\n", 400},
        {" / HTTP/1.0\r\n\r\n", 400},
        {"GET * HTTP/1.0\r\n\r\n", 400},
        {"GET /# HTTP/1.0\r\n\r\n", 400},
        {"GET /\x1f HTTP/1.0\r\n\r\n", 400},
        {"GET /\x7f HTTP/1.0\r\n\r\n", 400},
        {"GET /\x80 HTTP/1.0\r\n\r\n", 400},
        {"GET / HTTP/2.0\r\n\r\n", 400},
        {"GET / HTTP/1.2\r\n\r\n", 400},
        {"GET / HTTP/1.\r\n\r\n", 400},
        {"GET / HTTP/1.10\r\n\r\n", 400},
        {"GET / HTTX/1.0\r\n\r\n", 400},
        {"GET / HTTP/1.0 \r\n\r\n", 400},
        {"GET\r\n\r\n", 400}, {"GET /\r\n\r\n", 400}, {"\r\n\r\n", 400},
    };
    for (size_t i = 0; i < sizeof rows / sizeof *rows; ++i)
        if (http_parse(text(rows[i].input), strlen(rows[i].input)) != rows[i].expected || errno != EDOM)
            return 12;
    const unsigned char embedded[] = "GET /\0 HTTP/1.0\r\n\r\n";
    if (http_parse(embedded, sizeof embedded - 1) != 400 || http_parse(NULL, 0))
        return 13;
    for (size_t i = 0; i < sizeof ok - 1; ++i)
        if (http_parse(text(ok), i))
            return 14;
    unsigned char bytes[LIMIT + 2];
    memset(bytes, 'x', sizeof bytes);
    if (http_parse(bytes, LIMIT - 1) || http_parse(bytes, LIMIT) != 431 ||
        http_parse(bytes, LIMIT + 1) != 431)
        return 15;
    const char prefix[] = "GET / HTTP/1.0\r\nPad:";
    memcpy(bytes, prefix, sizeof prefix - 1);
    memcpy(bytes + LIMIT - 4, "\r\n\r\n", 4);
    if (http_parse(bytes, LIMIT) != 200 || http_parse(bytes, LIMIT + 1) != 200 ||
        http_parse(bytes, LIMIT - 1) != 0)
        return 16;
    memcpy(bytes + LIMIT - 4, "x\r\n\r\n", 5);
    if (http_parse(bytes, LIMIT + 1) != 431 || errno != EDOM)
        return 17;
    return parser_octets();
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "token")) return token();
    if (!strcmp(argv[1], "find")) return find();
    if (!strcmp(argv[1], "parse")) return parser();
    return 91;
}
