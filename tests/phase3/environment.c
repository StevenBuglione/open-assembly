#include <elf.h>
#include <errno.h>
#include <stdlib.h>
#include <unistd.h>

#include "check.h"

extern char **environ;
extern char **const __al_initial_envp;
extern const Elf64_auxv_t *const __al_auxv;

static int initial(char **envp)
{
    size_t count = 0;
    while (envp[count])
        ++count;
    REQUIRE(environ && environ != envp && envp == __al_initial_envp
            && __al_auxv == (const Elf64_auxv_t *)(envp + count + 1), 20);
    for (size_t i = 0; i <= count; ++i)
        REQUIRE(environ[i] == envp[i], 21);
    errno = ERROR_SENTINEL;
    REQUIRE(same(getenv("AL_STAGE3"), "one two") && same(getenv("AL_STAGE3_EMPTY"), "")
            && errno == ERROR_SENTINEL, 22);
    char *original = getenv("AL_STAGE3");
    REQUIRE(unsetenv("AL_STAGE3") == 0 && !getenv("AL_STAGE3") && errno == ERROR_SENTINEL, 23);
    REQUIRE(same(original, "one two") && !envp[count]
            && __al_auxv == (const Elf64_auxv_t *)(envp + count + 1), 24);
    for (size_t i = 0; i < count; ++i)
        if (same(envp[i], "AL_STAGE3=one two"))
            return 0;
    return 25;
}

static int lookup(void)
{
    static char long_name[] = "ALPHABET=wrong", first[] = "ALPHA=one=two";
    static char later[] = "ALPHA=later", malformed[] = "MALFORMED", empty[] = "EMPTY=";
    static char *app[] = {long_name, malformed, first, later, empty, NULL};
    environ = app;
    errno = ERROR_SENTINEL;
    REQUIRE(getenv("ALPHA") == first + 6 && same(getenv("ALPHA"), "one=two"), 30);
    REQUIRE(!getenv("ALPH") && !getenv("alpha") && !getenv("MALFORMED"), 31);
    REQUIRE(getenv("EMPTY") == empty + 6 && !*getenv("EMPTY"), 32);
    REQUIRE(!getenv(NULL) && !getenv("") && !getenv("ALPHA=one") && errno == ERROR_SENTINEL, 33);
    return 0;
}

static int insert(void)
{
    static char *empty[] = {NULL};
    environ = empty;
    char name[] = "COPY", value[] = "one=two";
    errno = ERROR_SENTINEL;
    REQUIRE(setenv(name, value, 1) == 0 && same(getenv("COPY"), "one=two"), 40);
    char *prior = getenv("COPY");
    name[0] = 'X';
    value[0] = 'X';
    REQUIRE(same(prior, "one=two") && !getenv("XOPY") && !empty[0], 41);
    REQUIRE(setenv("COPY", "ignored", 0) == 0 && getenv("COPY") == prior, 42);
    REQUIRE(setenv("COPY", prior + 4, -7) == 0 && same(getenv("COPY"), "two"), 43);
    REQUIRE(setenv("COPY", "", 1) == 0 && same(getenv("COPY"), "") && errno == ERROR_SENTINEL, 44);
    char **stable = environ;
    REQUIRE(setenv("", "a", 1) == -1 && errno == EINVAL && environ == stable, 45);
    REQUIRE(setenv(NULL, "a", 1) == -1 && errno == EINVAL && environ == stable, 46);
    REQUIRE(setenv("B=AD", "a", 1) == -1 && errno == EINVAL && environ == stable, 47);
    REQUIRE(setenv("COPY", NULL, 1) == -1 && errno == EINVAL && same(getenv("COPY"), ""), 48);
    REQUIRE(unsetenv("COPY") == 0, 49);
    return 0;
}

static int remove_all(void)
{
    static char first[] = "KEY=first", later[] = "KEY=later", prefix[] = "KEYX=keep";
    static char malformed[] = "KEY", other[] = "KEEP=ok";
    static char *app[] = {first, prefix, later, malformed, other, NULL};
    environ = app;
    errno = ERROR_SENTINEL;
    REQUIRE(unsetenv("KEY") == 0 && !getenv("KEY") && errno == ERROR_SENTINEL, 50);
    REQUIRE(environ == app && app[0] == prefix && app[1] == malformed && app[2] == other && !app[3], 51);
    REQUIRE(unsetenv("KEY") == 0 && errno == ERROR_SENTINEL, 52);
    REQUIRE(unsetenv("") == -1 && errno == EINVAL, 53);
    REQUIRE(unsetenv(NULL) == -1 && errno == EINVAL, 54);
    REQUIRE(unsetenv("KEYX=keep") == -1 && errno == EINVAL && same(getenv("KEYX"), "keep"), 55);
    return 0;
}

static int borrow(void)
{
    static char *empty[] = {NULL};
    environ = empty;
    char text[] = "BORROW=a", remove[] = "LORROW", absent[] = "ABSENT", bad[] = "=a", blank[] = "";
    errno = ERROR_SENTINEL;
    REQUIRE(putenv(text) == 0 && getenv("BORROW") == text + 7 && environ[0] == text, 60);
    text[7] = 'b';
    REQUIRE(same(getenv("BORROW"), "b"), 61);
    text[0] = 'L';
    REQUIRE(!getenv("BORROW") && getenv("LORROW") == text + 7, 62);
    REQUIRE(putenv(absent) == 0 && putenv(remove) == 0 && !getenv("LORROW")
            && same(text, "LORROW=b") && errno == ERROR_SENTINEL, 63);
    REQUIRE(putenv(bad) == -1 && errno == EINVAL, 64);
    REQUIRE(putenv(blank) == -1 && errno == EINVAL, 65);
    REQUIRE(putenv(NULL) == -1 && errno == EINVAL, 66);
    return 0;
}

static char large_value[LARGE_REQUEST + 1];

static int ownership(void)
{
    static char *empty[] = {NULL};
    environ = empty;
    for (size_t i = 0; i < LARGE_REQUEST; ++i)
        large_value[i] = (char)('a' + i % 26);
    REQUIRE(setenv("DUP", large_value, 1) == 0 && environ[0] && !environ[1], 70);
    char *owned = environ[0];
    static char *shared[3];
    shared[0] = shared[1] = owned;
    environ = shared;
    REQUIRE(setenv("DUP", "replacement", 1) == 0 && same(getenv("DUP"), "replacement"), 71);
    REQUIRE(environ[1] == owned && same(environ[1] + 4, large_value), 72);
    REQUIRE(unsetenv("DUP") == 0 && !getenv("DUP") && !environ[0], 73);

    large_value[0] = 'S';
    large_value[1] = 'U';
    large_value[2] = 'B';
    large_value[3] = '=';
    REQUIRE(setenv("BASE", large_value, 1) == 0, 74);
    shared[0] = getenv("BASE");
    shared[1] = NULL;
    REQUIRE(shared[0], 75);
    environ = shared;
    REQUIRE(setenv("APPEND", "visible", 1) == 0 && same(getenv("APPEND"), "visible"), 76);
    REQUIRE(getenv("SUB") == shared[0] + 4 && same(getenv("SUB"), large_value + 4), 77);
    REQUIRE(unsetenv("SUB") == 0 && unsetenv("APPEND") == 0 && !environ[0], 78);
    return 0;
}

enum { KEYS = 12, OPERATIONS = 4096 };

static int model(void)
{
    static char *empty[] = {NULL};
    environ = empty;
    char names[KEYS][3], borrowed[KEYS][5], expected[KEYS][2];
    int present[KEYS] = {0};
    for (size_t i = 0; i < KEYS; ++i) {
        names[i][0] = borrowed[i][0] = 'K';
        names[i][1] = borrowed[i][1] = (char)('A' + i);
        names[i][2] = expected[i][1] = borrowed[i][4] = '\0';
        borrowed[i][2] = '=';
        borrowed[i][3] = '?';
    }
    uint32_t state = UINT32_C(0x65a11ea3);
    for (size_t step = 0; step < OPERATIONS; ++step) {
        uint32_t word = next(&state);
        size_t key = word % KEYS;
        char value[] = {(char)('a' + (word >> 8) % 26), '\0'};
        errno = ERROR_SENTINEL;
        switch ((word >> 16) % 4) {
        case 0:
        case 1: {
            int overwrite = (word >> 24) & 1;
            REQUIRE(setenv(names[key], value, overwrite) == 0, 80);
            if (!present[key] || overwrite) {
                present[key] = 1;
                expected[key][0] = value[0];
            }
            break;
        }
        case 2:
            REQUIRE(unsetenv(names[key]) == 0, 81);
            present[key] = 0;
            break;
        default:
            borrowed[key][3] = value[0];
            REQUIRE(putenv(borrowed[key]) == 0 && getenv(names[key]) == borrowed[key] + 3, 82);
            present[key] = 1;
            expected[key][0] = value[0];
            break;
        }
        size_t active = 0;
        for (size_t i = 0; i < KEYS; ++i) {
            REQUIRE(same(getenv(names[i]), present[i] ? expected[i] : NULL), 83);
            active += (unsigned)present[i];
        }
        size_t count = 0;
        while (count <= KEYS && environ[count])
            ++count;
        REQUIRE(count == active && errno == ERROR_SENTINEL, 84);
    }
    for (size_t i = 0; i < KEYS; ++i)
        REQUIRE(unsetenv(names[i]) == 0, 85);
    REQUIRE(!environ[0], 86);
    return 0;
}

int main(int argc, char **argv, char **envp)
{
    REQUIRE(argc == 2, 10);
    if (same(argv[1], "initial"))
        return initial(envp);
    if (same(argv[1], "lookup"))
        return lookup();
    if (same(argv[1], "insert"))
        return insert();
    if (same(argv[1], "remove"))
        return remove_all();
    if (same(argv[1], "borrow"))
        return borrow();
    if (same(argv[1], "ownership"))
        return ownership();
    if (same(argv[1], "model"))
        return model();
    return 11;
}
