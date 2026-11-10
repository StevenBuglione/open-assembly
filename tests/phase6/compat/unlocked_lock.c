#include "../kernel_abi.h"
#include <stdio.h>

static int armed;
static unsigned locks, unlocks;

void __real___al_lock(void *);
void __real___al_unlock(void *);

void __wrap___al_lock(void *word)
{
    if (armed)
        ++locks;
    __real___al_lock(word);
}

void __wrap___al_unlock(void *word)
{
    if (armed)
        ++unlocks;
    __real___al_unlock(word);
}

int main(void)
{
    static char input_buffer[64], output_buffer[64], stdout_buffer[64];
    FILE *in = fopen("input", "r");
    FILE *out = fopen("output", "w");
    if (!in || !out || setvbuf(in, input_buffer, _IOFBF, sizeof input_buffer) ||
        setvbuf(out, output_buffer, _IOFBF, sizeof output_buffer) ||
        setvbuf(stdout, stdout_buffer, _IOFBF, sizeof stdout_buffer))
        return 10;

    armed = 1;
    int control = fgetc(in);
    armed = 0;
    if (control != 'A' || !locks || locks != unlocks)
        return 11;

    locks = unlocks = 0;
    armed = 1;
    int byte = getc_unlocked(in);
    int error = ferror_unlocked(in);
    int string = fputs_unlocked("file", out);
    int terminal = putchar_unlocked('U');
    armed = 0;
    if (locks || unlocks)
        return 12;
    if (byte != 'B' || error || string < 0 || terminal != 'U')
        return 13;
    if (fclose(in) || fclose(out) || fflush(stdout) || raw_unlink("output", 0))
        return 14;
    return 0;
}
