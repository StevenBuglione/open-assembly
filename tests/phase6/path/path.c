#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <spawn.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

static char *const arguments[] = {"caller-name", "a b", "-x", NULL};

static int make_file(const char *name, const char *content, mode_t mode)
{
    int fd = open(name, O_WRONLY | O_CREAT | O_EXCL, mode);
    if (fd < 0)
        return 0;
    size_t length = strlen(content);
    ssize_t count = write(fd, content, length);
    return close(fd) == 0 && count == (ssize_t)length;
}

static int prepare(void)
{
    return mkdir("first", 0700) == 0 &&
           mkdir("later", 0700) == 0 &&
           mkdir("deny", 0700) == 0 &&
           mkdir("wrong", 0700) == 0 &&
           make_file("regular", "", 0600) &&
           make_file("deny/tool", "#!/bin/sh\nexit 97\n", 0600) &&
           make_file("first/tool",
                     "#!/bin/sh\nprintf 'first %s [%s] [%s] %s\\n' \"$OA_ENV\" \"$1\" \"$2\" \"$#\"\n",
                     0700) &&
           make_file("later/tool", "#!/bin/sh\nprintf 'later\\n'\n", 0700) &&
           make_file("wrong/tool", "#!/bin/sh\nprintf 'wrong PATH\\n'\n", 0700) &&
           make_file("tool", "#!/bin/sh\nprintf 'current\\n'\n", 0700) &&
           make_file("first/plain", "printf 'script %s [%s] [%s] %s\\n' \"$0\" \"$1\" \"$2\" \"$#\"\n",
                     0700);
}

static int child_status(pid_t pid)
{
    int status = -1;
    if (pid < 1 || waitpid(pid, &status, 0) != pid || !WIFEXITED(status))
        return 89;
    return WEXITSTATUS(status);
}

static int direct_success(void)
{
    if (setenv("OA_ENV", "runtime-env", 1) || setenv("PATH", "wrong", 1))
        return 11;
    (void)execv("first/tool", arguments);
    return 12;
}

static int direct_missing(void)
{
    errno = EDOM;
    int result = execv("missing/file", arguments);
    if (result != -1)
        return 41;
    return errno == ENOENT ? 0 : 42;
}

static int search_success(void)
{
    if (setenv("PATH", "missing:regular:deny:first:later", 1))
        return 13;
    (void)execvp("tool", arguments);
    return 14;
}

static int search_error(void)
{
    if (setenv("PATH", "missing:regular:deny", 1))
        return 15;
    errno = EDOM;
    int result = execvp("tool", arguments);
    if (result != -1)
        return 53;
    return errno == EACCES ? 0 : 54;
}

static int default_search(void)
{
    char *const argv[] = {"explicit-shell", "-c", "printf 'default shell\\n'", NULL};
    if (unsetenv("PATH"))
        return 16;
    (void)execvp("sh", argv);
    return 17;
}

static int fallback(void)
{
    if (setenv("PATH", "first:later", 1))
        return 18;
    return execvp("plain", arguments) == -1 && errno == ENOEXEC ? 61 : 62;
}

static int spawn_search(const char *path)
{
    if (setenv("PATH", path, 1) || setenv("OA_ENV", "parent", 1))
        return 20;
    char *const envp[] = {"PATH=wrong", "OA_ENV=child", NULL};
    pid_t pid = -7654;
    errno = EDOM;
    int result = posix_spawnp(&pid, "tool", NULL, NULL, arguments, envp);
    if (result || pid <= 0)
        return 21;
#ifndef OA_PHASE6_HOST
    if (errno != EDOM)
        return 22;
#endif
    int status = child_status(pid);
    const char *value = getenv("OA_ENV");
    if (!value || strcmp(value, "parent"))
        return 24;
    return status;
}

static int spawn_failure(const char *path, const char *file, int error)
{
    if (setenv("PATH", path, 1))
        return 23;
    char *const envp[] = {"PATH=wrong", "OA_ENV=child", NULL};
    pid_t pid = -7654;
    errno = EDOM;
    int result = posix_spawnp(&pid, file, NULL, NULL, arguments, envp);
    if (result != error)
        return 72;
#ifndef OA_PHASE6_HOST
    if (errno != EDOM)
        return 73;
#endif
    return pid == -7654 ? 0 : 74;
}

static int search_large(int recover)
{
    char path[4096 + sizeof(":first")];
    memset(path, 'a', 4096);
    if (recover)
        memcpy(path + 4096, ":first", sizeof(":first"));
    else
        path[4096] = '\0';
    if (setenv("PATH", path, 1))
        return 25;
    int result = execvp("tool", arguments);
    if (recover)
        return 26;
    return result == -1 && errno == ENAMETOOLONG ? 0 : 27;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    const char *mode = argv[1];
    if (strcmp(mode, "execv-missing") == 0)
        return direct_missing();
    if (!prepare())
        return 91;
    if (strcmp(mode, "execv") == 0)
        return direct_success();
    if (strcmp(mode, "execvp-order") == 0)
        return search_success();
    if (strcmp(mode, "execvp-denied") == 0)
        return search_error();
    if (strcmp(mode, "execvp-default") == 0)
        return default_search();
    if (strcmp(mode, "execvp-fallback") == 0)
        return fallback();
    if (strcmp(mode, "spawnp") == 0)
        return spawn_search("missing:regular:deny:first:later");
    if (strcmp(mode, "spawnp-empty-element") == 0)
        return spawn_search("missing::later");
    if (strcmp(mode, "spawnp-format") == 0)
        return spawn_failure("first", "plain", ENOEXEC);
    if (strcmp(mode, "spawnp-denied") == 0)
        return spawn_failure("missing:regular:deny", "tool", EACCES);
    if (strcmp(mode, "execvp-long") == 0)
        return search_large(0);
    if (strcmp(mode, "execvp-long-then-valid") == 0)
        return search_large(1);
    const char *path = strcmp(mode, "execvp-empty") == 0 ? "" : "missing::later";
    if (setenv("PATH", path, 1))
        return 28;
    if (strcmp(mode, "execvp-slash") == 0)
        (void)execvp("later/tool", arguments);
    else if (strcmp(mode, "execvp-empty") == 0 || strcmp(mode, "execvp-empty-element") == 0)
        (void)execvp("tool", arguments);
    return 29;
}
