#include <stddef.h>
#include <stdlib.h>

_Noreturn void __al_panic(const char *message, size_t length);

static void unwanted(void)
{
    _Exit(20);
}

int main(void)
{
    static const char payload[] = "panic\0detail\n!";
    if (atexit(unwanted) != 0)
        return 21;
    __al_panic(payload, sizeof payload - 2);
}
