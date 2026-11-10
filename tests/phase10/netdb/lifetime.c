#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

extern void *__real_malloc(size_t);
extern void *__real_calloc(size_t, size_t);
extern void __real_free(void *);

enum { MAX_LIVE = 64 };
static void *live[MAX_LIVE];
static int armed, calls, fail_at, tracking_error;

static int inject(void)
{
    if (armed && ++calls == fail_at) {
        errno = ENOMEM;
        return 1;
    }
    return 0;
}

static void *observe(void *pointer)
{
    if (armed && pointer) {
        for (int i = 0; i < MAX_LIVE; ++i) {
            if (!live[i]) {
                live[i] = pointer;
                return pointer;
            }
        }
        tracking_error = 1;
    }
    return pointer;
}

void *__wrap_malloc(size_t size)
{
    return inject() ? NULL : observe(__real_malloc(size));
}

void *__wrap_calloc(size_t count, size_t size)
{
    return inject() ? NULL : observe(__real_calloc(count, size));
}

void __wrap_free(void *pointer)
{
    if (armed && pointer) {
        for (int i = 0; i < MAX_LIVE; ++i) {
            if (live[i] == pointer) {
                live[i] = NULL;
                break;
            }
        }
    }
    __real_free(pointer);
}

static int allocations(void)
{
    int count = 0;
    for (int i = 0; i < MAX_LIVE; ++i)
        count += live[i] != NULL;
    return count;
}

static int lookup(struct addrinfo **list)
{
    const struct addrinfo hints = {.ai_family = AF_INET,
                                   .ai_flags = AI_NUMERICHOST | AI_NUMERICSERV | AI_CANONNAME};
    return getaddrinfo("192.0.2.77", "137", &hints, list);
}

static int detached(void)
{
    struct addrinfo sentinel, *list = &sentinel;
    errno = EDOM;
    armed = 1;
    if (lookup(&list) || !list || list == &sentinel || !list->ai_next ||
        list->ai_next->ai_next || !list->ai_canonname || errno != EDOM || tracking_error)
        return 50;
    struct addrinfo *suffix = list->ai_next;
    list->ai_next = NULL;
    int before = allocations();
    freeaddrinfo(list);
    if (allocations() <= 0 || allocations() >= before || errno != EDOM)
        return 51;
    if (suffix->ai_family != AF_INET || suffix->ai_socktype != SOCK_DGRAM ||
        !suffix->ai_addr || suffix->ai_addrlen != sizeof(struct sockaddr_in))
        return 52;
    freeaddrinfo(suffix);
    freeaddrinfo(NULL);
    armed = 0;
    return allocations() || tracking_error || errno != EDOM ? 53 : 0;
}

static int failures(void)
{
    struct addrinfo *list;
    if (detached())
        return 54;
    int successful_calls = calls;
    if (successful_calls <= 0 || successful_calls > MAX_LIVE)
        return 55;
    for (int index = 1; index <= successful_calls; ++index) {
        struct addrinfo sentinel;
        list = &sentinel;
        fail_at = index;
        calls = 0;
        errno = EDOM;
        armed = 1;
        int status = lookup(&list);
        armed = 0;
        if (status != EAI_MEMORY || list || errno != EDOM || calls < fail_at ||
            allocations() || tracking_error)
            return 56;
    }
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "free"))
        return detached();
    if (!strcmp(argv[1], "oom"))
        return failures();
    return 91;
}
