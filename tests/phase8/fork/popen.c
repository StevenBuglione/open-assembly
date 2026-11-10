#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static int mark_fd;

static void prepare(void) { (void)write(mark_fd, "P", 1); }
static void parent(void) { (void)write(mark_fd, "A", 1); }
static void child(void) { (void)write(mark_fd, "C", 1); }

int main(void)
{
    int markers[2];
    if (pipe2(markers, O_NONBLOCK | O_CLOEXEC))
        return 90;
    mark_fd = markers[1];
    if (pthread_atfork(prepare, parent, child))
        return 91;

    static const char expected[] = "popen-bypass\n";
    char bytes[sizeof expected + 1], marks[sizeof bytes];
    FILE *stream = popen("printf 'popen-bypass\\n'; exit 17", "r");
    if (!stream)
        return 11;
    size_t count = fread(bytes, 1, sizeof bytes, stream);
    if (count != sizeof expected - 1 || memcmp(bytes, expected, count) ||
        !feof(stream) || ferror(stream))
        return 12;
    int status = pclose(stream);
    if (status < 0 || !WIFEXITED(status) || WEXITSTATUS(status) != 17)
        return 13;
    if (read(markers[0], marks, sizeof marks) != -1 || errno != EAGAIN)
        return 14;

    /* The same installed observers must run on a public fork. */
    pid_t process = fork();
    if (process == 0)
        _exit(0);
    if (process < 0 || waitpid(process, &status, 0) != process ||
        !WIFEXITED(status) || WEXITSTATUS(status) != 0)
        return 15;
    if (read(markers[0], marks, sizeof marks) != 3 || marks[0] != 'P' ||
        !((marks[1] == 'A' && marks[2] == 'C') || (marks[1] == 'C' && marks[2] == 'A')))
        return 16;
    if (close(markers[0]) || close(markers[1]))
        return 92;
    return write(STDOUT_FILENO, bytes, count) == (ssize_t)(sizeof expected - 1) ? 0 : 93;
}
