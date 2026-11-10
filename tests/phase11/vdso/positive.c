#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <time.h>

int main(void)
{
    struct timespec before, after;
    if (clock_gettime(CLOCK_REALTIME, &before))
        return 90;
    errno = EDOM;
    time_t saved = 0;
    time_t first = time(&saved);
    time_t second = time(NULL);
    int preserved = errno == EDOM;
    if (clock_gettime(CLOCK_REALTIME, &after))
        return 90;
    return preserved && first == saved && before.tv_sec <= first && first <= second &&
           second <= after.tv_sec ? 0 : 11;
}
