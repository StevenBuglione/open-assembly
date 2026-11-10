#include <unistd.h>

/* The gate enables GCC's explicit stack protection for this main. */
__attribute__((stack_protect))
int main(void)
{
    static const char message[] = "Hello from C!\n";
    return write(STDOUT_FILENO, message, sizeof message - 1) == sizeof message - 1
        ? 0 : 42;
}
