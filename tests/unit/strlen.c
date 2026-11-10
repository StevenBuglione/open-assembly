#define _GNU_SOURCE

#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <setjmp.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#include "../fuzz/strlen_inputs.h"
#include "../oracle/strlen_vectors.h"

extern size_t __al_test_strlen(const char *s);
extern unsigned al_check_strlen_abi(const char *s, size_t *result);

static int unit_checks(void)
{
    for (size_t i = 0; i < sizeof strlen_vectors / sizeof strlen_vectors[0]; i++) {
        size_t actual = __al_test_strlen(strlen_vectors[i].bytes);
        if (actual != strlen_vectors[i].expected) {
            fprintf(stderr, "FAIL unit reference:byte-count: %s expected %zu, got %zu\n",
                    strlen_vectors[i].name, strlen_vectors[i].expected, actual);
            return 1;
        }
    }
    printf("PASS unit reference:byte-count %zu vectors\n",
           sizeof strlen_vectors / sizeof strlen_vectors[0]);
    return 0;
}

static int abi_checks(void)
{
    static const char *const samples[] = {"", "n", "string\0suffix", "\xff\x80"};
    /* Oracle abi:sysv-amd64. The bit order is shared with tests/abi/strlen.asm. */
    static const char *const flags[] = {
        "RSP", "DF", "RBX", "RBP", "R12", "R13", "R14", "R15",
        "MXCSR control", "x87 control word", "x87 stack",
    };

    for (size_t i = 0; i < sizeof samples / sizeof samples[0]; i++) {
        size_t result;
        unsigned failures = al_check_strlen_abi(samples[i], &result);
        if (failures) {
            fprintf(stderr, "FAIL abi abi:sysv-amd64: sample %zu returned %zu, mask %#x:",
                    i, result, failures);
            for (size_t bit = 0; bit < sizeof flags / sizeof flags[0]; bit++)
                if (failures & (1u << bit))
                    fprintf(stderr, " %s", flags[bit]);
            fputc('\n', stderr);
            return 1;
        }
    }
    printf("PASS abi abi:sysv-amd64 %zu call probes\n", sizeof samples / sizeof samples[0]);
    return 0;
}

static sigjmp_buf guard_fault;
static volatile sig_atomic_t in_guard_probe;

static void guard_signal(int signal_number)
{
    if (in_guard_probe)
        siglongjmp(guard_fault, signal_number);
    _exit(2);
}

static int guarded_strlen(const char *input, size_t *result)
{
    int fault = sigsetjmp(guard_fault, 1);
    if (fault) {
        in_guard_probe = 0;
        return fault;
    }

    in_guard_probe = 1;
    *result = __al_test_strlen(input);
    in_guard_probe = 0;
    return 0;
}

static int guard_probe(unsigned char *page, size_t page_size, size_t length, int at_end)
{
    const char *edge = at_end ? "end" : "start";
    if (mprotect(page, page_size, PROT_READ | PROT_WRITE) != 0) {
        perror("ERROR guard: writable page");
        return 2;
    }

    unsigned char *input = at_end ? page + page_size - length - 1 : page;
    for (size_t i = 0; i < length; i++)
        input[i] = 1 + i % 255;
    input[length] = 0;

    if (mprotect(page, page_size, PROT_READ) != 0) {
        perror("ERROR guard: read-only page");
        return 2;
    }

    size_t actual;
    int fault = guarded_strlen((const char *)input, &actual);
    if (fault) {
        fprintf(stderr, "FAIL guard reference:page-protection: %s length %zu raised signal %d\n",
                edge, length, fault);
        return 1;
    }
    if (actual != length) {
        fprintf(stderr, "FAIL guard reference:byte-count: %s length %zu, got %zu\n",
                edge, length, actual);
        return 1;
    }
    return 0;
}

static int guard_checks(void)
{
    long reported_page_size = sysconf(_SC_PAGESIZE);
    if (reported_page_size < 128 || (unsigned long)reported_page_size > SIZE_MAX / 3) {
        fputs("ERROR guard: unusable page size\n", stderr);
        return 2;
    }
    size_t page_size = (size_t)reported_page_size;
    unsigned char *mapping = mmap(NULL, 3 * page_size, PROT_NONE,
                                  MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mapping == MAP_FAILED) {
        perror("ERROR guard: mmap");
        return 2;
    }

    unsigned char *page = mapping + page_size;
    struct sigaction action = {.sa_handler = guard_signal};
    sigemptyset(&action.sa_mask);
    int status = 0;
    size_t probes = 0;
    if (sigaction(SIGSEGV, &action, NULL) != 0 || sigaction(SIGBUS, &action, NULL) != 0) {
        perror("ERROR guard: sigaction");
        status = 2;
    }
    for (size_t length = 0; status == 0 && length < 128; length++) {
        for (int at_end = 0; status == 0 && at_end <= 1; at_end++) {
            status = guard_probe(page, page_size, length, at_end);
            probes++;
        }
    }
    for (size_t boundary = 128; status == 0 && boundary < page_size; boundary *= 2) {
        for (size_t length = boundary - 1; status == 0 && length <= boundary + 1 && length < page_size; length++) {
            status = guard_probe(page, page_size, length, 1);
            probes++;
        }
    }
    if (status == 0) {
        status = guard_probe(page, page_size, page_size - 1, 1);
        probes++;
    }
    if (munmap(mapping, 3 * page_size) != 0) {
        perror("ERROR guard: munmap");
        return 2;
    }
    if (status == 0)
        printf("PASS guard reference:page-protection and reference:byte-count %zu probes\n", probes);
    return status;
}

struct libc_oracle {
    pid_t pid;
    int socket;
    const char *name;
};

static int start_oracle(struct libc_oracle *oracle, const char *path)
{
    int sockets[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, sockets) != 0)
        return -1;

    pid_t child = fork();
    if (child == 0) {
        close(sockets[0]);
        if (dup2(sockets[1], STDIN_FILENO) == -1 || dup2(sockets[1], STDOUT_FILENO) == -1)
            _exit(2);
        if (sockets[1] != STDIN_FILENO && sockets[1] != STDOUT_FILENO)
            close(sockets[1]);
        execl(path, path, (char *)NULL);
        _exit(2);
    }

    int error = errno;
    close(sockets[1]);
    if (child == -1) {
        close(sockets[0]);
        errno = error;
        return -1;
    }
    oracle->pid = child;
    oracle->socket = sockets[0];
    return 0;
}

static int finish_oracle(const struct libc_oracle *oracle)
{
    close(oracle->socket);
    int status;
    pid_t waited;
    do {
        waited = waitpid(oracle->pid, &status, 0);
    } while (waited == -1 && errno == EINTR);
    return waited == oracle->pid && WIFEXITED(status) && WEXITSTATUS(status) == 0 ? 0 : -1;
}

static int send_bytes(int socket, const void *data, size_t size)
{
    const unsigned char *bytes = data;
    while (size > 0) {
        ssize_t sent = send(socket, bytes, size, MSG_NOSIGNAL);
        if (sent == -1 && errno == EINTR)
            continue;
        if (sent <= 0)
            return -1;
        bytes += sent;
        size -= (size_t)sent;
    }
    return 0;
}

static int receive_bytes(int socket, void *data, size_t size)
{
    unsigned char *bytes = data;
    while (size > 0) {
        ssize_t received = read(socket, bytes, size);
        if (received == -1 && errno == EINTR)
            continue;
        if (received <= 0)
            return -1;
        bytes += received;
        size -= (size_t)received;
    }
    return 0;
}

static int compare(const struct libc_oracle *oracle, const char *mode, const char *name,
                   size_t index, const unsigned char *bytes, uint32_t size, size_t first_zero)
{
    uint64_t expected;
    if (send_bytes(oracle->socket, &size, sizeof size) != 0 ||
        send_bytes(oracle->socket, bytes, size) != 0 ||
        receive_bytes(oracle->socket, &expected, sizeof expected) != 0) {
        fprintf(stderr, "ERROR %s: %s oracle communication failed on case %zu\n",
                mode, oracle->name, index);
        return 2;
    }

    if (expected != first_zero) {
        fprintf(stderr, "ERROR %s: %s oracle returned %" PRIu64 " for case %zu with first zero at %zu\n",
                mode, oracle->name, expected, index, first_zero);
        return 2;
    }

    size_t actual = __al_test_strlen((const char *)bytes);
    if (actual != expected) {
        fprintf(stderr, "FAIL %s diff:%s: %s case %zu expected %" PRIu64 ", got %zu\n",
                mode, oracle->name, name, index, expected, actual);
        return 1;
    }
    return 0;
}

static int differential_checks(const struct libc_oracle *oracle)
{
    unsigned char storage[4098 + 64];
    static const size_t lengths[] = {
        0, 1, 2, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65,
        127, 128, 129, 255, 256, 257, 1023, 1024, 1025, 4095, 4096, 4097,
    };

    size_t count = 0;
    for (size_t offset = 0; offset < 64; offset++) {
        unsigned char *bytes = storage + offset;
        for (size_t i = 0; i < sizeof lengths / sizeof lengths[0]; i++) {
            size_t length = lengths[i];
            for (size_t j = 0; j < length; j++)
                bytes[j] = 1 + (j + offset) % 255;
            bytes[length] = 0;
            int status = compare(oracle, "differential", "length/alignment sweep", count++,
                                 bytes, (uint32_t)length + 1, length);
            if (status)
                return status;
        }
    }
    for (unsigned byte = 0; byte <= UCHAR_MAX; byte++) {
        unsigned char bytes[] = {(unsigned char)byte, 0xff, 0, 0xa5, 0};
        size_t length = byte == 0 ? 0 : 2;
        int status = compare(oracle, "differential", "all byte values with embedded NUL", count++,
                             bytes, sizeof bytes, length);
        if (status)
            return status;
    }
    printf("PASS differential diff:%s and reference:byte-count %zu cases\n", oracle->name, count);
    return 0;
}

static int now_ns(uint64_t *value)
{
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) {
        perror("ERROR fuzz: monotonic clock");
        return -1;
    }
    *value = (uint64_t)now.tv_sec * 1000000000 + (uint64_t)now.tv_nsec;
    return 0;
}

static int fuzz_checks(const struct libc_oracle *oracle, unsigned seconds)
{
    struct strlen_fuzz_input input;
    uint32_t state = STRLEN_FUZZ_SEED;
    uint64_t now;
    if (now_ns(&now) != 0)
        return 2;
    uint64_t deadline = now + (uint64_t)seconds * 1000000000;

    size_t count = 0;
    while (count < STRLEN_FUZZ_MIN_CASES || now < deadline) {
        generate_input(&input, &state, count);
        int status = compare(oracle, "fuzz", "seed 0x41534d30", count,
                             input.bytes, (uint32_t)input.size, input.first_zero);
        if (status)
            return status;
        count++;
        if (count >= STRLEN_FUZZ_MIN_CASES && now_ns(&now) != 0)
            return 2;
    }
    printf("PASS fuzz diff:%s and reference:byte-count %zu cases seed %#" PRIx32 "\n",
           oracle->name, count, STRLEN_FUZZ_SEED);
    return 0;
}

static int oracle_checks(const char *mode, const char *path, unsigned seconds)
{
    const char *name = getenv("OPEN_ASSEMBLY_STRLEN_ORACLE");
    if (!name)
        name = "glibc";
    if (strcmp(name, "glibc") != 0 && strcmp(name, "musl") != 0) {
        fprintf(stderr, "ERROR %s: unrecognized libc oracle %s\n", mode, name);
        return 2;
    }
    struct libc_oracle oracle = {.name = name};
    if (start_oracle(&oracle, path) != 0) {
        fprintf(stderr, "ERROR %s: launch %s oracle: %s\n", mode, name, strerror(errno));
        return 2;
    }
    int status = strcmp(mode, "differential") == 0
        ? differential_checks(&oracle) : fuzz_checks(&oracle, seconds);
    if (finish_oracle(&oracle) != 0) {
        fprintf(stderr, "ERROR %s: %s oracle did not exit successfully\n", mode, name);
        return 2;
    }
    return status;
}

int main(int argc, char **argv)
{
    if (argc == 2) {
        if (strcmp(argv[1], "unit") == 0)
            return unit_checks();
        if (strcmp(argv[1], "abi") == 0)
            return abi_checks();
        if (strcmp(argv[1], "guard") == 0)
            return guard_checks();
    }
    if (argc == 3 && strcmp(argv[1], "differential") == 0)
        return oracle_checks(argv[1], argv[2], 0);
    if ((argc == 3 || argc == 4) && strcmp(argv[1], "fuzz") == 0) {
        unsigned long seconds = 1;
        if (argc == 4) {
            char *end;
            seconds = strtoul(argv[3], &end, 10);
            if (argv[3][0] < '0' || argv[3][0] > '9' || *end != '\0' || seconds > 300) {
                fputs("ERROR fuzz: duration must be an integer from 0 to 300 seconds\n", stderr);
                return 2;
            }
        }
        return oracle_checks(argv[1], argv[2], (unsigned)seconds);
    }

    fputs("Usage: checks unit|abi|guard\n"
          "       checks differential ORACLE\n"
          "       checks fuzz ORACLE [SECONDS]\n", stderr);
    return 2;
}
