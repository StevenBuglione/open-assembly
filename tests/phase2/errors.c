#include <errno.h>
#include <limits.h>
#include <string.h>

#include "test.h"

#define TEST_NAME strerror
extern __typeof__(TEST_NAME) CANDIDATE;
static __typeof__(TEST_NAME) *volatile host = TEST_NAME;

static int abi(void)
{
    return ABI_CALL(UINT64_C(0xdeadbeef00000000) | (unsigned)EINVAL);
}

static int fallback(const char *text)
{
    static const char message[] = "No error information";
    size_t i = 0;
    while (message[i] && message[i] == text[i])
        ++i;
    return text[i] == message[i];
}

static uint64_t fingerprint(const char *text)
{
    uint64_t result = UINT64_C(0xcbf29ce484222325);
    while (*text)
        result = (result ^ (unsigned char)*text++) * UINT64_C(1099511628211);
    return result;
}

/* Linux x86-64 UAPI leaves 41 and 58 unassigned and assigns EFTYPE to 134. */
static const struct {
    int number;
    int unknown;
} cases[] = {
    {0, 1}, {-1, 1}, {INT_MIN, 1}, {INT_MAX, 1}, {-4096, 1},
    {41, 1}, {58, 1}, {134, 0}, {135, 1},
    {EDOM, 0}, {EILSEQ, 0}, {ERANGE, 0}, {EINTR, 0}, {EBADF, 0}, {EINVAL, 0},
};

static int sample(size_t index, uint32_t *state, int compare_host)
{
    size_t count = sizeof cases / sizeof cases[0];
    size_t slot = index < count ? index : phase2_next(state) % count;
    int number = cases[slot].number;
    if (compare_host) {
        const char *message = host(number);
        if (!message || !*message)
            return phase2_error("host did not provide a message for error %d", number);
    }

    errno = 1029;
    const char *message = CANDIDATE(number);
    if (!message || !*message || errno != 1029)
        return phase2_fail("invalid message or changed errno for error %d", number);
    if (fallback(message) != cases[slot].unknown)
        return phase2_fail("unexpected fallback classification for error %d", number);
    uint64_t contents = fingerprint(message);
    const char *other = CANDIDATE(cases[slot].unknown ? EINVAL : 0);
    if (!other || !*other || fingerprint(message) != contents || errno != 1029)
        return phase2_fail("later strerror call changed a prior message or errno");
    return 0;
}

static int guard(void)
{
    uint32_t state = 1;
    for (size_t i = 0; i < sizeof cases / sizeof cases[0]; ++i) {
        int status = sample(i, &state, 0);
        if (status)
            return status;
    }
    return 0;
}

const struct phase2_fixture fixture = {
    "strerror", "project:strerror-messages", "project:strerror-messages",
    "project:strerror-messages", sizeof cases / sizeof cases[0], abi, guard, sample,
};
