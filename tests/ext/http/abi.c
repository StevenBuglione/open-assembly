#include <http.h>
#include <stdint.h>
#include <string.h>

extern unsigned phase2_abi_probe(uintptr_t target, const uint64_t arguments[6]);
extern unsigned phase2_abi_probe_result(uintptr_t target, const uint64_t arguments[6],
                                        uint64_t result[2]);

int main(int argc, char **argv)
{
    static const unsigned char data[] = "HEAD /x HTTP/1.1\r\nHost:x\r\n\r\n";
    uint64_t args[6] = {(uintptr_t)data, sizeof data - 1};
    uintptr_t target;
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "token")) {
        target = (uintptr_t)http_is_token_byte;
        static const char allowed[] =
            "!#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
        const uint64_t upper[] = {UINT64_C(0xc13183d8ba877a00), UINT64_C(0x3ece7c2745788500)};
        for (size_t i = 0; i < sizeof upper / sizeof *upper; ++i)
            for (unsigned byte = 0; byte < 256; ++byte) {
                uint64_t result[2];
                unsigned expected = byte && strchr(allowed, (int)byte);
                args[0] = upper[i] | byte;
                if (phase2_abi_probe_result(target, args, result) || (uint32_t)result[0] != expected)
                    return 13;
            }
        return 0;
    } else if (!strcmp(argv[1], "find")) {
        target = (uintptr_t)http_find_header_end;
    } else if (!strcmp(argv[1], "parse")) {
        target = (uintptr_t)http_parse;
    } else {
        return 91;
    }
    return phase2_abi_probe(target, args) != 0;
}
