#include <stdlib.h>
#include <unistd.h>

static int calls;

static void emit(char byte)
{
    if (write(STDOUT_FILENO, &byte, 1) != 1)
        _Exit(25);
}

static void count(void)
{
    if (++calls > 32)
        _Exit(26);
}

static void finish(void)
{
    if (calls != 31)
        _Exit(27);
    emit('F');
}

static void add_to_full_registry(void)
{
    if (atexit(count) != 0 || atexit(count) == 0)
        _Exit(28);
    emit('R');
}

int main(void)
{
    if (atexit(finish) != 0)
        return 20;
    for (int i = 0; i < 30; ++i)
        if (atexit(count) != 0)
            return 21;
    if (atexit(add_to_full_registry) != 0)
        return 22;
    if (atexit(count) == 0)
        return 23;
    return 0;
}
