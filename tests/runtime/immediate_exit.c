#include <stdlib.h>
#include <unistd.h>

static void unwanted(void)
{
    char byte = '!';
    write(STDOUT_FILENO, &byte, 1);
}

int main(int argc, char **argv)
{
    if (argc != 2 || atexit(unwanted) != 0)
        return 20;
    if (argv[1][0] == 'C')
        _Exit(0x171);
    _exit(-2);
}
