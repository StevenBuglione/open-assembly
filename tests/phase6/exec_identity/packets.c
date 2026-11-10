#include "files.h"

#include <linux/prctl.h>
#include <signal.h>
#include <time.h>

struct stimulus { uint64_t mode, value; };
struct report {
    int32_t kind, returned, error, image;
    uint64_t arguments, environment, flags;
};
struct observed {
    int64_t returned, error, wait_status;
    uint64_t scenario, image, arguments, environment, flags;
};
_Static_assert(sizeof(struct stimulus) == 16 && sizeof(struct observed) == 64 &&
               sizeof(struct report) == 40, "Linux LP64 wire widths");

enum { REPLACED = 1, RETURNED = 2, FAILED_EXEC_EXIT = 91 };
enum { FIRST = 1, LATER = 2, CURRENT = 3 };
static const char replacement[] = "--exec-packet-replacement";
static volatile unsigned old_image_marker;

struct scenario {
    const char *file, *path;
    int image, error;
};

static const struct scenario direct[] = {
    {"first/tool", "PATH=later:first", FIRST, 0},
    {"later/tool", "PATH=first", LATER, 0},
    {"./tool", "PATH=later", CURRENT, 0},
    {"only", "PATH=first", 0, ENOENT},
    {"deny/tool", "PATH=first", 0, EACCES},
    {"regular/tool", "PATH=first", 0, ENOTDIR},
    {"plain", "PATH=first", 0, ENOEXEC},
    {"first/loop", "PATH=later", 0, ELOOP},
    {"first", "PATH=later", 0, EACCES},
};
static const struct scenario search[] = {
    {"tool", "PATH=missing:regular:deny:first:later", FIRST, 0},
    {"tool", "PATH=later:first", LATER, 0},
    {"tool", "PATH=missing::first", CURRENT, 0},
    {"tool", "PATH=", CURRENT, 0},
    {"later/tool", "PATH=first", LATER, 0},
    {"tool", "PATH=missing:regular:deny", 0, EACCES},
    {"tool", "PATH=regular:missing", 0, ENOENT},
    {"regular/tool", "PATH=first", 0, ENOTDIR},
    {"loop", "PATH=first:later", 0, ELOOP},
    {"", "PATH=first", 0, ENOENT},
};

static int read_row(struct stimulus *input)
{
    size_t done = 0;
    while (done < sizeof *input) {
        long n = raw_read(STDIN_FILENO, (char *)input + done, sizeof *input - done);
        if (n == -EINTR)
            continue;
        if (n < 0 || (!n && done))
            return -1;
        if (!n)
            return 0;
        done += (size_t)n;
    }
    return 1;
}

static void hex_text(char text[17], uint64_t value)
{
    static const char digits[] = "0123456789abcdef";
    for (unsigned i = 0; i < 16; ++i)
        text[i] = digits[(value >> (60 - i * 4)) & 15];
    text[16] = 0;
}

static int read_hex(const char *text, uint64_t *value)
{
    *value = 0;
    for (unsigned i = 0; i < 16; ++i) {
        unsigned c = (unsigned char)text[i];
        unsigned digit = c >= '0' && c <= '9' ? c - '0' :
                         c >= 'a' && c <= 'f' ? c - 'a' + 10 : 16;
        if (digit == 16)
            return 0;
        *value = (*value << 4) | digit;
    }
    return text[16] == 0;
}

static char *copy(char *out, const char *text)
{
    while ((*out = *text++))
        ++out;
    return out;
}

struct vectors {
    char seed[17], pid[17], argument[23], token[26], path[64];
    char *args[10], *env[4], *ambient[3];
};

static void make_vectors(struct vectors *vectors, enum operation operation, char *name,
                         const char *path, uint64_t seed, uint64_t pid)
{
    hex_text(vectors->seed, seed);
    hex_text(vectors->pid, pid);
    copy(copy(vectors->argument, "value "), vectors->seed);
    copy(copy(vectors->token, "OA_TOKEN="), vectors->seed);
    copy(vectors->path, path);
    vectors->args[0] = "exec packet image";
    vectors->args[1] = (char *)replacement;
    vectors->args[2] = name;
    vectors->args[3] = vectors->seed;
    vectors->args[4] = vectors->pid;
    vectors->args[5] = vectors->argument;
    vectors->args[6] = vectors->path;
    vectors->args[7] = "two words";
    vectors->args[8] = "";
    vectors->args[9] = NULL;
    int reversed = (seed >> 62) & 1;
    vectors->env[reversed ? 2 : 0] = vectors->token;
    vectors->env[1] = "OA_EMPTY=";
    vectors->env[reversed ? 0 : 2] = vectors->path;
    vectors->env[3] = NULL;
    if (operation == EXECVE && (seed >> 63))
        vectors->env[0] = NULL;
    vectors->ambient[0] = "OA_PARENT_ONLY=stale";
    vectors->ambient[1] = "PATH=deny";
    vectors->ambient[2] = NULL;
}

static uint64_t vector_digest(char *const vector[], size_t omit)
{
    uint64_t result = 1;
    for (size_t i = 0; vector[i]; ++i) {
        if (i == omit)
            continue;
        const unsigned char *bytes = (const unsigned char *)vector[i];
        while (*bytes)
            result = result * 257 + *bytes++;
        result *= 257;
    }
    return result;
}

static int same_vector(char *const actual[], char *const expected[])
{
    size_t i = 0;
    for (; expected[i]; ++i)
        if (!actual[i] || !same_text(actual[i], expected[i]))
            return 0;
    return actual[i] == NULL;
}

static int exit_code(uint64_t seed)
{
    return 100 + (int)(seed & 63);
}

static int selected_image(void)
{
    char path[4096];
    long count = kernel_call(__NR_readlink, (long)"/proc/self/exe", (long)path,
                             sizeof path - 1, 0, 0, 0);
    if (count <= 0 || count >= (long)sizeof path)
        return 0;
    path[count] = 0;
    static const char *const suffixes[] = {
        "/exec-packet-root/first/tool", "/exec-packet-root/later/tool", "/exec-packet-root/tool",
    };
    for (unsigned i = 0; i < sizeof suffixes / sizeof *suffixes; ++i) {
        size_t length = 0;
        while (suffixes[i][length])
            ++length;
        if ((size_t)count >= length && same_text(path + count - length, suffixes[i]))
            return (int)i + 1;
    }
    return 0;
}

static int replacement_main(int argc, char **argv, char **envp)
{
    if (argc != 9 || argv[9])
        return 31;
    enum operation operation = operation_from(argv[2]);
    uint64_t seed, pid;
    if (operation == BAD_OPERATION || !read_hex(argv[3], &seed) ||
        !read_hex(argv[4], &pid))
        return 31;
    size_t path_length = 0;
    while (path_length < sizeof ((struct vectors *)0)->path && argv[6][path_length])
        ++path_length;
    if (path_length == sizeof ((struct vectors *)0)->path)
        return 31;
    struct vectors expected;
    make_vectors(&expected, operation, argv[2], argv[6], seed, pid);
    if (!same_vector(argv, expected.args))
        return 31;
    if (!same_vector(envp, expected.env))
        return 32;
    int image = selected_image();
    if (!image)
        return 33;
    if ((uint64_t)identity() != pid || old_image_marker)
        return 34;
    struct report result = {REPLACED, 0, 0, image,
                            vector_digest(argv, 4), vector_digest(envp, SIZE_MAX), 1};
    return write_all(STDOUT_FILENO, &result, sizeof result) ? exit_code(seed) : 94;
}

static _Noreturn void raw_exit(int code)
{
    (void)kernel_call(__NR_exit_group, code, 0, 0, 0, 0, 0);
    __builtin_trap();
}

static _Noreturn void call_in_child(enum operation operation, char *name,
                                    const struct scenario *scenario, uint64_t seed)
{
    uint64_t pid = (uint64_t)identity();
    struct vectors vectors, expected;
    make_vectors(&vectors, operation, name, scenario->path, seed, pid);
    make_vectors(&expected, operation, name, scenario->path, seed, pid);
    char **current = operation == EXECVE ? vectors.ambient : vectors.env;
    environ = current;
    old_image_marker = 0x4798;
    errno = TEST_ERRNO;
    int returned = attempt(operation, scenario->file, vectors.args, vectors.env);
    int error = errno;
    if ((uint64_t)identity() != pid || environ != current || old_image_marker != 0x4798 ||
        !same_vector(vectors.args, expected.args) ||
        !same_vector(vectors.env, expected.env) ||
        !same_vector(vectors.ambient, expected.ambient))
        raw_exit(35);
    struct report result = {RETURNED, returned, error, 0, vector_digest(vectors.args, 4),
                            vector_digest(vectors.env, SIZE_MAX), 2};
    raw_exit(write_all(STDOUT_FILENO, &result, sizeof result) ? FAILED_EXEC_EXIT : 94);
}

static long wait_raw(pid_t pid, int *status, int options)
{
    long result;
    do {
        result = kernel_call(__NR_wait4, pid, (long)status, options, 0, 0, 0);
    } while (result == -EINTR);
    return result;
}

static void terminate(pid_t pid)
{
    (void)kernel_call(__NR_kill, -pid, SIGKILL, 0, 0, 0, 0);
    (void)kernel_call(__NR_kill, pid, SIGKILL, 0, 0, 0, 0);
}

static int wait_bounded(pid_t pid, int *status)
{
    struct timespec delay = {0, 1000000};
    for (unsigned i = 0; i < 1500; ++i) {
        long result = wait_raw(pid, status, WNOHANG);
        if (result)
            return result == pid;
        (void)kernel_call(__NR_nanosleep, (long)&delay, 0, 0, 0, 0, 0);
    }
    terminate(pid);
    (void)wait_raw(pid, NULL, 0);
    return 0;
}

static int collect(pid_t child, int reader, struct report *report, int *status)
{
    struct { int fd; short events, revents; } pollfd = {reader, 1, 0};
    long polled = kernel_call(__NR_poll, (long)&pollfd, 1, 1500, 0, 0, 0);
    long count = -1;
    if (polled == 1) {
        do {
            count = raw_read(reader, report, sizeof *report);
        } while (count == -EINTR);
    } else {
        terminate(child);
    }
    int waited = wait_bounded(child, status);
    char extra;
    long tail = waited ? raw_read(reader, &extra, 1) : -1;
    int closed = raw_close(reader) == 0;
    if (!waited || !closed || !WIFEXITED(*status) || tail != 0)
        return 95;
    if (count == (long)sizeof *report)
        return 0;
    int code = WEXITSTATUS(*status);
    return count == 0 && code >= 31 && code <= 35 ? code : 95;
}

static int run_row(enum operation operation, char *name, struct stimulus input,
                   struct observed *output)
{
    unsigned index = (unsigned)(operation == EXECVP ? input.mode % (sizeof search / sizeof *search)
                                                     : input.mode % (sizeof direct / sizeof *direct));
    const struct scenario *scenario = operation == EXECVP ? &search[index] : &direct[index];
    int ends[2];
    if (kernel_call(__NR_pipe2, (long)ends, O_CLOEXEC | O_NONBLOCK, 0, 0, 0, 0))
        return 90;
    long parent = identity();
    long child = kernel_call(__NR_fork, 0, 0, 0, 0, 0, 0);
    if (child < 0) {
        (void)raw_close(ends[0]);
        (void)raw_close(ends[1]);
        return 90;
    }
    if (!child) {
        if (ends[0] < 3 || ends[1] < 3 ||
            kernel_call(__NR_prctl, PR_SET_PDEATHSIG, SIGKILL, 0, 0, 0, 0) ||
            kernel_call(__NR_getppid, 0, 0, 0, 0, 0, 0) != parent ||
            kernel_call(__NR_setpgid, 0, 0, 0, 0, 0, 0) || raw_close(ends[0]) ||
            kernel_call(__NR_dup2, ends[1], STDOUT_FILENO, 0, 0, 0, 0) != STDOUT_FILENO ||
            raw_close(ends[1]) || raw_close(STDIN_FILENO) || raw_close(STDERR_FILENO))
            raw_exit(90);
        call_in_child(operation, name, scenario, input.value);
    }
    int closed = raw_close(ends[1]) == 0;
    struct report report = {0};
    int status = 0;
    int collected = collect((pid_t)child, ends[0], &report, &status);
    if (!closed || collected)
        return closed ? collected : 91;
    int replacement_expected = scenario->error == 0;
    if (report.kind != (replacement_expected ? REPLACED : RETURNED) ||
        report.returned != (replacement_expected ? 0 : -1) || report.error != scenario->error)
        return 21;
    if (report.image != scenario->image || status != ((replacement_expected ?
            exit_code(input.value) : FAILED_EXEC_EXIT) << 8))
        return 22;

    struct vectors expected;
    make_vectors(&expected, operation, name, scenario->path, input.value, 0);
    if (report.arguments != vector_digest(expected.args, 4) ||
        report.environment != vector_digest(expected.env, SIZE_MAX) ||
        report.flags != (replacement_expected ? 1U : 2U))
        return 23;
    *output = (struct observed){report.returned, report.error, status, index,
        (unsigned)report.image, report.arguments, report.environment, report.flags};
    return 0;
}

int main(int argc, char **argv, char **envp)
{
    if (argc > 1 && same_text(argv[1], replacement))
        raw_exit(replacement_main(argc, argv, envp));
    if (argc != 2)
        return 92;
    enum operation operation = operation_from(argv[1]);
    if (operation == BAD_OPERATION)
        return 92;

    int source = (int)raw_open(AT_FDCWD, argv[0], O_RDONLY | O_CLOEXEC, 0);
    int parent = (int)raw_open(AT_FDCWD, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC, 0);
    if (source < 0 || parent < 0)
        return 92;
    (void)kernel_call(__NR_umask, 0, 0, 0, 0, 0, 0);
    if (raw_mkdir(fixture_root, 0700))
        return 92;
    if (change_dir(fixture_root)) {
        (void)raw_unlink(fixture_root, K_AT_REMOVEDIR);
        return 92;
    }

    int initialized = populate(source);
    int closed_source = raw_close(source) == 0;
    int result = initialized && closed_source ? 0 : 92;
    struct stimulus input;
    while (!result) {
        int received = read_row(&input);
        if (received <= 0) {
            if (received < 0)
                result = 96;
            break;
        }
        struct observed output;
        result = run_row(operation, argv[1], input, &output);
        if (!result && !write_all(STDOUT_FILENO, &output, sizeof output))
            result = 96;
    }
    int removed = remove_fixture(parent, !initialized);
    return raw_close(parent) || !removed ? 97 : result;
}
