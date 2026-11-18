#include "exercise.h"
#include "model.c"
struct stimulus { uint64_t selector, seed; };
_Static_assert(sizeof(struct stimulus) == 16, "fixed input width");
static int read_packet(struct stimulus *p)
{
    size_t used = 0;
    while (used < sizeof *p) {
        long got = raw_read(0, (unsigned char *)p + used, sizeof *p - used);
        if (!got) return used ? -1 : 0;
        if (got < 0) return -1;
        used += (size_t)got;
    }
    return 1;
}
int main(int argc, char **argv)
{
    if (argc < 2 || argc > 3) return 90;
    enum operation op = operation_from(argv[1]);
    if (op == OPERATIONS) return 90;
    size_t page = page_size();
    if (page < 1024 || page > sizeof storage_a / 12 || page % 4) return 93;
    struct arena a = {0}, b = {0};
    int guard = argc == 3 && same_text(argv[2], "guard");
    int ordinary = argc == 3 && same_text(argv[2], "ordinary");
    if (argc == 3 && !guard && !ordinary) return 90;
    if (guard && (arena_open(&a, page) || arena_open(&b, page))) return 91;
    int status = 0;
    if (argc == 3) {
        for (unsigned kind = 0; !status && kind < (op == BYTE_MOVE ? 7U : 1U); ++kind)
            for (unsigned i = 0; !status && i < LENGTHS; ++i)
                for (unsigned edge = 0; !status && edge < 4U; ++edge)
                    status = exercise(op, i + ((uint64_t)kind << 8) + ((uint64_t)edge << 62),
                                      197 + i + edge, page, guard ? &a : NULL,
                                      guard ? &b : NULL, NULL);
    } else {
        struct stimulus p;
        int read_status;
        while (!status && (read_status = read_packet(&p)) > 0) {
            struct observed out;
            status = exercise(op, p.selector, p.seed, page, NULL, NULL, &out);
            if (!status && raw_write(1, &out, sizeof out) != (long)sizeof out) status = 95;
        }
        if (!status && read_status < 0) status = 94;
    }
    if (guard && (arena_close(&a) || arena_close(&b)) && !status) status = 92;
    return status;
}
