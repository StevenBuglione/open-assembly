#define OA_COPY_ABI 1
#include "exercise.h"
#include "model.c"
int main(int argc, char **argv)
{
    if (argc != 2) return 90;
    enum operation op = operation_from(argv[1]);
    if (op == OPERATIONS) return 90;
    size_t page = page_size();
    /* Positive bulk request first, with readable initialized surrounding data. */
    for (unsigned kind = 0; kind < (op == BYTE_MOVE ? 7U : 1U); ++kind)
        for (unsigned i = 0; i < LENGTHS; ++i) {
            int status = exercise(op, i + ((uint64_t)kind << 8), 197 + i, page, NULL, NULL, NULL);
            if (status) return status == 22 || status == 23 ? 13 : status;
        }
    return 0;
}
