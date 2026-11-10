#include <string.h>

_Static_assert(_Generic(&strlen, size_t (*)(const char *): 1, default: 0),
               "generated strlen must match the hosted test's candidate prototype");
