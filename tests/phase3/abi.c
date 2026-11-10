#include <errno.h>
#include <stdlib.h>

#include "check.h"

extern unsigned phase2_abi_probe(uintptr_t function, const uint64_t arguments[6]);

#define ABI(function, ...) \
    phase2_abi_probe((uintptr_t)(function), (const uint64_t[6]){__VA_ARGS__})
#define ADDRESS(pointer) ((uintptr_t)(pointer))

int main(void)
{
    REQUIRE(!ABI(malloc, 33), 20);
    REQUIRE(!ABI(calloc, 9, 7), 21);
    REQUIRE(!ABI(realloc, 0, 23), 22);
    REQUIRE(!ABI(aligned_alloc, 64, 29), 23);

    void *out = NULL;
    REQUIRE(!ABI(posix_memalign, ADDRESS(&out), 64, 19) && aligned(out, 64), 24);
    REQUIRE(!ABI(free, ADDRESS(out)), 25);

    static const char key[] = "AL_ABI", original[] = "initial", replacement[] = "replacement";
    static char borrowed[] = "AL_ABI=borrowed";
    REQUIRE(setenv(key, original, 1) == 0, 26);
    REQUIRE(!ABI(getenv, ADDRESS(key)), 27);
    REQUIRE(!ABI(setenv, ADDRESS(key), ADDRESS(replacement), UINT64_C(0xdeadbeef00000000))
            && same(getenv(key), original), 28);
    REQUIRE(!ABI(putenv, ADDRESS(borrowed)) && getenv(key) == borrowed + 7, 29);
    REQUIRE(!ABI(unsetenv, ADDRESS(key)) && !getenv(key), 30);
    return 0;
}
