#include <json.h>
#include <stdint.h>
#include <string.h>

extern unsigned phase2_abi_probe(uintptr_t target, const uint64_t arguments[6]);

int main(int argc, char **argv)
{
    const unsigned char object[] = "{\"x\":[1,true]}";
    size_t work[7], tokens[24];
    uint64_t args[6] = {(uintptr_t)object, sizeof object - 1};
    uintptr_t target;
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "string")) {
        target = (uintptr_t)json_scan_string;
        args[2] = 1;
    } else if (!strcmp(argv[1], "number")) {
        target = (uintptr_t)json_scan_number;
        args[2] = 6;
    } else if (!strcmp(argv[1], "lex")) {
        target = (uintptr_t)json_lex;
        args[2] = 1;
        args[3] = (uintptr_t)tokens;
    } else if (!strcmp(argv[1], "parse")) {
        target = (uintptr_t)json_parse;
        args[2] = (uintptr_t)work;
        args[3] = 2;
        args[4] = (uintptr_t)tokens;
        args[5] = 6;
    } else {
        return 91;
    }
    return phase2_abi_probe(target, args) != 0;
}
