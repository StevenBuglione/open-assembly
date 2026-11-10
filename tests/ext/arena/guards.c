#include <arena.h>
#include <errno.h>
#include <stdint.h>

/* Linux x86-64 mmap/mprotect/munmap. Two writable pages place state and output
   at independent ends, surrounded by inaccessible pages. */
extern long __al_syscall(long, long, long, long, long, long, long);

int main(void)
{
    const long page = 4096, size = 5 * page;
    long mapping = __al_syscall(9, 0, size, 0, 0x22, -1, 0);
    if (mapping < 0)
        return 90;
    uintptr_t base = (uintptr_t)mapping;
    if (__al_syscall(10, mapping + page, page, 3, 0, 0, 0) ||
        __al_syscall(10, mapping + 3 * page, page, 3, 0, 0, 0))
        return 91;

    for (int side = 0; side <= 1; ++side) {
        size_t *state = (size_t *)(base + page + side * (page - sizeof(size_t[3])));
        void **result = (void **)(base + 3 * page + (1 - side) * (page - sizeof(void *)));
        uintptr_t inaccessible = base + 2 * page;
        errno = EDOM;
        if (arena_init(state, (void *)inaccessible, (size_t)page) ||
            state[0] != inaccessible || state[1] != (size_t)page || state[2] || errno != EDOM)
            return 11;
        if (arena_alloc(state, 9, 16, result) || (uintptr_t)*result != inaccessible ||
            state[0] != inaccessible || state[1] != (size_t)page || state[2] != 9 || errno != EDOM)
            return 12;
        if (arena_alloc(state, 0, 16, result) || (uintptr_t)*result != inaccessible + 16 ||
            state[2] != 9 || errno != EDOM)
            return 13;
        if (arena_alloc(state, (size_t)page, 1, result) != -ENOSPC || state[2] != 9 ||
            (uintptr_t)*result != inaccessible + 16 || errno != EDOM)
            return 14;
        if (arena_reset(state) || state[0] != inaccessible || state[1] != (size_t)page ||
            state[2] || errno != EDOM)
            return 15;
    }
    return __al_syscall(11, mapping, size, 0, 0, 0, 0) ? 92 : 0;
}
