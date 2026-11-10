#define _GNU_SOURCE
#include <errno.h>
#include <stdio.h>
#include <unistd.h>

#include "../phase4/file.h"

#undef feof
#undef ferror
#undef clearerr
#undef fileno

extern unsigned phase2_abi_probe_result(uintptr_t function, const uint64_t arguments[6],
                                        uint64_t result[2]);

enum { EOF_QUERY, ERROR_QUERY, CLEAR, DESCRIPTOR };

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    unsigned operation;
    uintptr_t target;
    if (same(argv[1], "feof")) {
        operation = EOF_QUERY;
        target = (uintptr_t)feof;
    } else if (same(argv[1], "ferror")) {
        operation = ERROR_QUERY;
        target = (uintptr_t)ferror;
    } else if (same(argv[1], "clearerr")) {
        operation = CLEAR;
        target = (uintptr_t)clearerr;
    } else if (same(argv[1], "fileno")) {
        operation = DESCRIPTOR;
        target = (uintptr_t)fileno;
    } else {
        return 91;
    }
    struct file_fixture file;
    FILE *stream = stderr;
    if (operation != DESCRIPTOR) {
        if (!file_fixture_open(&file, "R", 1) || !(stream = fopen(file.path, "rb")))
            return 92;
        if (operation != ERROR_QUERY && (fseek(stream, 0, SEEK_END) || fgetc(stream) != EOF))
            return 93;
        if (operation != EOF_QUERY && fputc('Q', stream) != EOF)
            return 94;
    }
    uint64_t result[2];
    errno = EDOM;
    if (phase2_abi_probe_result(target, (const uint64_t[6]){(uintptr_t)stream}, result) || errno != EDOM)
        return 11;
    if ((operation == EOF_QUERY || operation == ERROR_QUERY) && (uint32_t)result[0] == 0)
        return 12;
    if (operation == CLEAR && (feof(stream) || ferror(stream)))
        return 13;
    if (operation == DESCRIPTOR && (uint32_t)result[0] != STDERR_FILENO)
        return 14;
    return operation == DESCRIPTOR || (fclose(stream) == 0 && file_fixture_close(&file)) ? 0 : 95;
}
