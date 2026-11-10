#include <asm/unistd.h>
#include <errno.h>
#include <linux/mman.h>
#include <stdlib.h>
#include <unistd.h>

#include "check.h"

extern char **environ;
long __real___al_syscall(long number, long a1, long a2, long a3, long a4, long a5, long a6);

static struct {
    size_t minimum, maximum;
    unsigned injected, mapped, unmapped, lost;
    int deny, armed;
    struct {
        long address, length;
    } live[16];
} trace;

static void arm(size_t minimum, int deny)
{
    trace.minimum = minimum;
    trace.maximum = minimum + 1024 * 1024;
    trace.deny = deny;
    trace.armed = 1;
}

long __wrap___al_syscall(long number, long a1, long a2, long a3, long a4, long a5, long a6)
{
    int selected = trace.armed && number == __NR_mmap && (a4 & MAP_ANONYMOUS)
        && (a3 & (PROT_READ | PROT_WRITE)) == (PROT_READ | PROT_WRITE)
        && (size_t)a2 >= trace.minimum && (size_t)a2 <= trace.maximum;
    if (selected && trace.deny) {
        ++trace.injected;
        return -ENOMEM;
    }
    long result = __real___al_syscall(number, a1, a2, a3, a4, a5, a6);
    if (selected && (unsigned long)result < (unsigned long)-4095) {
        ++trace.mapped;
        size_t slot;
        for (slot = 0; slot < sizeof trace.live / sizeof trace.live[0]; ++slot) {
            if (!trace.live[slot].length) {
                trace.live[slot].address = result;
                trace.live[slot].length = a2;
                break;
            }
        }
        if (slot == sizeof trace.live / sizeof trace.live[0])
            ++trace.lost;
    }
    if (trace.armed && number == __NR_munmap && result == 0) {
        for (size_t slot = 0; slot < sizeof trace.live / sizeof trace.live[0]; ++slot) {
            if (trace.live[slot].length == a2 && trace.live[slot].address == a1) {
                trace.live[slot].length = 0;
                ++trace.unmapped;
                break;
            }
        }
    }
    return result;
}

static char *append_text(char *out, const char *text)
{
    while (*text)
        *out++ = *text++;
    return out;
}

static char *append_number(char *out, unsigned number)
{
    char reverse[10];
    size_t count = 0;
    do {
        reverse[count++] = (char)('0' + number % 10);
        number /= 10;
    } while (number);
    while (count)
        *out++ = reverse[--count];
    return out;
}

static int report(void)
{
    char buffer[64];
    trace.armed = 0;
    char *end = append_number(append_text(buffer, "injected="), trace.injected);
    end = append_number(append_text(end, " mmap="), trace.mapped);
    end = append_number(append_text(end, " munmap="), trace.unmapped);
    *end++ = '\n';
    return write(STDOUT_FILENO, buffer, (size_t)(end - buffer)) == end - buffer ? 0 : 99;
}

static int check_failure(const char *kind)
{
    void *out = &out;
    unsigned char *old = NULL;
    if (same(kind, "realloc")) {
        old = malloc(73);
        REQUIRE(old, 20);
        for (size_t i = 0; i < 73; ++i)
            old[i] = (unsigned char)(i * 17 + 3);
    }
    errno = ERROR_SENTINEL;
    arm(LARGE_REQUEST, 1);
    if (same(kind, "malloc")) {
        REQUIRE(!malloc(LARGE_REQUEST) && errno == ENOMEM, 21);
    } else if (same(kind, "calloc")) {
        REQUIRE(!calloc(LARGE_REQUEST, 1) && errno == ENOMEM, 22);
    } else if (same(kind, "aligned")) {
        REQUIRE(!aligned_alloc(4096, LARGE_REQUEST) && errno == ENOMEM, 23);
    } else if (same(kind, "posix")) {
        REQUIRE(posix_memalign(&out, 4096, LARGE_REQUEST) == ENOMEM
                && out == &out && errno == ERROR_SENTINEL, 24);
    } else if (same(kind, "realloc")) {
        REQUIRE(!realloc(old, LARGE_REQUEST) && errno == ENOMEM, 25);
        for (size_t i = 0; i < 73; ++i)
            REQUIRE(old[i] == (unsigned char)(i * 17 + 3), 26);
        free(old);
    } else {
        return 11;
    }
    REQUIRE(trace.injected && !trace.mapped && !trace.unmapped, 27);
    return report();
}

static int release(void)
{
    arm(LARGE_REQUEST, 0);
    errno = ERROR_SENTINEL;
    unsigned char *bytes = malloc(LARGE_REQUEST);
    REQUIRE(bytes && trace.mapped && !trace.unmapped, 80);
    bytes[0] = 1;
    bytes[LARGE_REQUEST - 1] = 9;
    free(bytes);
    free(NULL);
    REQUIRE(!trace.injected && !trace.lost && trace.unmapped == trace.mapped
            && errno == ERROR_SENTINEL, 81);
    return report();
}

static char long_value[LARGE_REQUEST + 1];

static int env_string_failure(void)
{
    char original[] = "TARGET=prior", untouched[] = "KEEP=original";
    char *prior[] = {original, untouched, NULL};
    environ = prior;
    for (size_t i = 0; i < LARGE_REQUEST; ++i)
        long_value[i] = 'x';
    errno = ERROR_SENTINEL;
    arm(LARGE_REQUEST, 1);
    REQUIRE(setenv("TARGET", long_value, 1) == -1 && errno == ENOMEM, 40);
    REQUIRE(environ == prior && prior[0] == original && prior[1] == untouched && !prior[2]
            && getenv("TARGET") == original + 7 && same(getenv("KEEP"), "original"), 41);
    REQUIRE(trace.injected && !trace.mapped && !trace.unmapped, 42);
    return report();
}

enum { BORROWED_COUNT = 32768 };
static char *borrowed_vector[BORROWED_COUNT + 1];

static int env_vector_failure(int use_putenv)
{
    char borrowed[] = "OTHER=keep", addition[] = "INSERT=new";
    for (size_t i = 0; i < BORROWED_COUNT; ++i)
        borrowed_vector[i] = borrowed;
    environ = borrowed_vector;
    errno = ERROR_SENTINEL;
    arm(sizeof borrowed_vector, 1);
    int result = use_putenv ? putenv(addition) : setenv("INSERT", "new", 1);
    REQUIRE(result == -1 && errno == ENOMEM && trace.injected && !trace.mapped && !trace.unmapped, 50);
    REQUIRE(environ == borrowed_vector && !environ[BORROWED_COUNT] && !getenv("INSERT"), 51);
    for (size_t i = 0; i < BORROWED_COUNT; ++i)
        REQUIRE(environ[i] == borrowed, 52);
    REQUIRE(getenv("OTHER") == borrowed + 6 && same(addition, "INSERT=new"), 53);
    return report();
}

static int churn(void)
{
    enum { STEPS = 48 };
    for (size_t i = 0; i < LARGE_REQUEST; ++i)
        long_value[i] = 'x';
    arm(LARGE_REQUEST, 0);
    for (size_t step = 0; step < STEPS; ++step) {
        long_value[0] = (char)('a' + step % 26);
        REQUIRE(setenv("CHURN", long_value, 1) == 0, 60);
        char *stored = getenv("CHURN");
        REQUIRE(stored && stored != long_value && stored[0] == long_value[0]
                && stored[LARGE_REQUEST - 1] == 'x' && !stored[LARGE_REQUEST], 61);
    }
    REQUIRE(unsetenv("CHURN") == 0 && !getenv("CHURN"), 62);
    REQUIRE(trace.mapped && trace.mapped == trace.unmapped && !trace.injected && !trace.lost, 63);
    return report();
}

int main(int argc, char **argv)
{
    REQUIRE(argc == 2, 10);
    if (same(argv[1], "release"))
        return release();
    if (same(argv[1], "env-string"))
        return env_string_failure();
    if (same(argv[1], "env-vector-set"))
        return env_vector_failure(0);
    if (same(argv[1], "env-vector-put"))
        return env_vector_failure(1);
    if (same(argv[1], "env-churn"))
        return churn();
    return check_failure(argv[1]);
}
