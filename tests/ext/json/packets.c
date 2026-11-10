#include <errno.h>
#include <json.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

enum { STRING, NUMBER, LEX, PARSE };
struct result {
    int64_t status;
    uint64_t error;
    size_t words[28];
};
_Static_assert(sizeof(struct result) == 240, "LP64 result packet");

static const char *const documents[] = {
    "{\"a\":[true,false,null],\"a\":\"\\uD834\\uDD1E\"}",
    "\t[-0,1.25e-12,7E+31]\r\n", "\"a\\u0000\\/\\b\\f\\r\\n\\t\"",
    "\"\xc2\x80\xe0\xa0\x80\xf4\x8f\xbf\xbf\"", "[[[[0]]]]", "{\"\":{}, \"b\":[]}",
    "01", "1.", "0E+", "{\"a\":1,}", "[true false]", "\"\\uD800!\"",
    "\"\xed\xa0\x80\"", "\"\xf0\x8f\xbf\xbf\"", "trueX", "\xef\xbb\xbf""null"
};

static size_t decimal(unsigned char *out, const unsigned char *packet)
{
    uint32_t value = 0;
    for (unsigned i = 0; i < 4; ++i)
        value |= (uint32_t)packet[8 + i] << (8 * i);
    unsigned char reverse[10];
    size_t count = 0, end = 0;
    do {
        reverse[count++] = (unsigned char)('0' + value % 10);
        value /= 10;
    } while (value);
    if (packet[1] & 1)
        out[end++] = '-';
    while (count)
        out[end++] = reverse[--count];
    if (packet[2] & 1) {
        memcpy(out + end, ".025", 4);
        end += 4;
    }
    if (packet[2] & 2) {
        memcpy(out + end, "e+09", 4);
        end += 4;
    }
    return end;
}

static void observe(unsigned operation, const unsigned char *packet, struct result *result)
{
    unsigned char data[80];
    size_t length;
    unsigned mode = packet[0] & 7;
    size_t index = packet[1] % (sizeof documents / sizeof *documents);
    if (mode == 0) {
        length = packet[1] % 57;
        memcpy(data, packet + 8, length);
    } else if (mode == 1 && operation == NUMBER) {
        length = decimal(data, packet);
    } else {
        if (mode == 1 && operation == STRING)
            index = 2 + packet[1] % 2;
        length = strlen(documents[index]);
        if (mode == 2)
            length = packet[5] % (length + 1);
        size_t prefix = mode == 4 ? packet[7] % 4 : mode == 6 ? packet[7] % 7 : 0;
        memset(data, mode == 4 ? ' ' : '[', prefix);
        memcpy(data + prefix, documents[index], length);
        if (mode == 3)
            data[packet[5] % length] = packet[8];
        length += prefix;
        if (mode == 5)
            data[length++] = packet[8];
        if (mode == 6) {
            memset(data + length, ']', prefix);
            length += prefix;
        }
    }
    size_t offset = (packet[6] & 1) && operation != PARSE ? packet[2] % (length + 2) : 0;
    if (mode == 1 && operation == NUMBER)
        offset = 0;
    for (size_t i = 0; i < sizeof result->words / sizeof *result->words; ++i)
        result->words[i] = UINT64_C(0x8de1ea30ab5f4307);
    errno = EDOM;
    size_t work[19];
    switch (operation) {
    case STRING: result->status = json_scan_string(data, length, offset); break;
    case NUMBER: result->status = json_scan_number(data, length, offset); break;
    case LEX: result->status = json_lex(data, length, offset, result->words); break;
    default:
        result->status = json_parse(data, length, work, packet[3] % 9,
                                    result->words, packet[4] % 8);
        break;
    }
    result->error = (uint64_t)errno;
}

static int transfer(void *memory, size_t size, int writing)
{
    size_t offset = 0;
    while (offset < size) {
        unsigned char *bytes = (unsigned char *)memory + offset;
        ssize_t count = writing ? write(STDOUT_FILENO, bytes, size - offset) :
                                  read(STDIN_FILENO, bytes, size - offset);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            return count == 0 && !offset && !writing ? 0 : -1;
        offset += (size_t)count;
    }
    return 1;
}

int main(int argc, char **argv)
{
    const char *const names[] = {"string", "number", "lex", "parse"};
    if (argc != 2)
        return 90;
    unsigned operation = 0;
    while (operation < sizeof names / sizeof *names && strcmp(argv[1], names[operation]))
        ++operation;
    if (operation == sizeof names / sizeof *names)
        return 91;
    unsigned char packet[64];
    int received;
    while ((received = transfer(packet, sizeof packet, 0)) == 1) {
        struct result output;
        observe(operation, packet, &output);
        if (transfer(&output, sizeof output, 1) != 1)
            return 92;
    }
    return received < 0 ? 93 : 0;
}
