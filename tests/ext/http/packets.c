#include <errno.h>
#include <http.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

enum { LIMIT = 8192 };
static const char *const heads[] = {
    "GET / HTTP/1.1\r\nHost:x\r\n\r\n",
    "HEAD /?q HTTP/1.0\r\n\r\n",
    "OPTIONS / HTTP/1.1\r\nHost:x\r\n\r\n",
    "GET / HTTP/1.1\r\nHost:x:65535\r\nContent-Length:000\r\n\r\n",
    "GET / HTTP/1.1\r\nHost:x:65536\r\n\r\n",
    "GET / HTTP/1.1\r\nHost:x\r\nTransfer-Encoding:identity\r\n\r\n",
    "GET / HTTP/1.1\r\nHost:x\r\nHost:y\r\n\r\n",
    "GET / HTTP/1.0\r\nX:\t ~\r\n\r\n"
};

static size_t make_span(unsigned char *bytes, const unsigned char *packet)
{
    unsigned mode = packet[0] & 7;
    if (mode == 0 || mode == 5) {
        size_t length = packet[1] % 57;
        memcpy(bytes, packet + 8, length);
        if (mode == 5 && length >= 4)
            memcpy(bytes + packet[2] % (length - 3), "\r\n\r\n", 4);
        return length;
    }
    if (mode >= 6) {
        const char prefix[] = "GET / HTTP/1.0\r\nPad:";
        size_t end = (LIMIT - 8) + packet[1] % 17;
        memset(bytes, 'x', end);
        memcpy(bytes, prefix, sizeof prefix - 1);
        memcpy(bytes + end - 4, "\r\n\r\n", 4);
        if (mode == 7)
            bytes[end - 1] = packet[2];
        return end;
    }
    const char *head = heads[packet[1] % (sizeof heads / sizeof *heads)];
    size_t length = strlen(head);
    if (mode == 2)
        length = packet[2] % (length + 1);
    memcpy(bytes, head, length);
    if (mode == 3)
        bytes[packet[2] % length] = packet[3];
    if (mode == 4) {
        size_t tail = packet[2] % 57;
        memcpy(bytes + length, packet + 8, tail);
        length += tail;
    }
    return length;
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
    if (argc != 2)
        return 90;
    int token = !strcmp(argv[1], "token"), find = !strcmp(argv[1], "find");
    if (!token && !find && strcmp(argv[1], "parse"))
        return 91;
    unsigned char packet[64], bytes[LIMIT + 8];
    int received;
    while ((received = transfer(packet, sizeof packet, 0)) == 1) {
        size_t length = token ? 0 : make_span(bytes, packet);
        errno = EDOM;
        uint64_t value = token ? http_is_token_byte(packet[1]) :
                         find ? http_find_header_end(bytes, length) : http_parse(bytes, length);
        uint64_t result[] = {value, (uint64_t)errno};
        if (transfer(result, sizeof result, 1) != 1)
            return 92;
    }
    return received < 0 ? 93 : 0;
}
