#include <stdlib.h>
#include <unistd.h>

static void emit(char byte)
{
    if (write(STDOUT_FILENO, &byte, 1) != 1)
        _Exit(25);
}

static void first(void) { emit('A'); }
static void third(void) { emit('C'); }
static void fourth(void) { emit('D'); }

static void second(void)
{
    emit('B');
    if (atexit(third) != 0 || atexit(fourth) != 0)
        _Exit(26);
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 20;
    if (atexit(first) != 0 || atexit(second) != 0)
        return 21;
    emit('M');
    if (argv[1][0] == 'e')
        exit(0x134);
    return 0x134;
}
