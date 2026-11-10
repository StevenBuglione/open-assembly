#include <pthread.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

static const int readonly_values[] = {31, 73, 101};
static int writable_values[] = {11, 19, 29, 43};

const int *const oa_pie_relro_pointer = &readonly_values[1];
int *oa_pie_data_pointer = &writable_values[1];

static _Thread_local int *volatile tls_pointer = &writable_values[2];
static _Thread_local const int *volatile tls_constant = &readonly_values[2];
_Alignas(64) static _Thread_local volatile unsigned long tls_cookie = 0x2fbb146ba8732111ul;

static int amplify(int n)
{
    return n * 5 + 8;
}

static int (*volatile code_pointer)(int) = amplify;

struct thread_args {
    int *volatile *parent_slot;
    unsigned index;
    int passed;
};

static int original_tls(void)
{
    return tls_pointer == &writable_values[2] && *tls_pointer == 29 &&
           tls_constant == &readonly_values[2] && *tls_constant == 101 &&
           tls_cookie == 0x2fbb146ba8732111ul && (uintptr_t)&tls_cookie % 64 == 0;
}

static void *worker(void *argument)
{
    struct thread_args *args = argument;
    if (!original_tls() || &tls_pointer == args->parent_slot)
        return NULL;
    tls_pointer = &writable_values[args->index];
    tls_constant = &readonly_values[0];
    tls_cookie ^= 0x3300u;
    args->passed = tls_pointer == &writable_values[args->index] &&
                   tls_constant == &readonly_values[0] && tls_cookie == 0x2fbb146ba8731211ul;
    return args;
}

int main(int argc, char **argv)
{
    if (argc < 2 || argc > 3 || (strcmp(argv[1], "pie") && strcmp(argv[1], "exec")) ||
        (argc == 3 && strcmp(argv[2], "hold")))
        return 90;

    const int *const volatile *readonly_slot = &oa_pie_relro_pointer;
    int *volatile *writable_slot = &oa_pie_data_pointer;
    if (*readonly_slot != &readonly_values[1] || **readonly_slot != 73 ||
        *writable_slot != &writable_values[1] || **writable_slot != 19 ||
        code_pointer(7) != 43)
        return 11;
    *writable_slot = &writable_values[3];
    if (*writable_slot != &writable_values[3] || **writable_slot != 43 || **readonly_slot != 73)
        return 12;
    if (!original_tls())
        return 13;

    tls_pointer = &writable_values[0];
    tls_constant = &readonly_values[1];
    tls_cookie = 0xe48d01be42bb6143ul;
    for (unsigned i = 1; i <= 2; ++i) {
        struct thread_args args = {&tls_pointer, i, 0};
        pthread_t thread;
        void *result = NULL;
        if (pthread_create(&thread, NULL, worker, &args) || pthread_join(thread, &result) ||
            result != &args || !args.passed)
            return 14;
        if (tls_pointer != &writable_values[0] || *tls_pointer != 11 ||
            tls_constant != &readonly_values[1] || tls_cookie != 0xe48d01be42bb6143ul)
            return 15;
    }

    static const char ready[] = "static-pie pointers ok\n";
    if (write(STDOUT_FILENO, ready, sizeof ready - 1) != sizeof ready - 1)
        return 91;
    if (argc == 3) {
        char byte = 0;
        if (read(STDIN_FILENO, &byte, 1) != 1 || byte != 'q')
            return 92;
    }
    return 0;
}
