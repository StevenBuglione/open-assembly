/* C17 7.8.1 format specifiers checked against the selected stdint types. */
#include <inttypes.h>
#include <stdio.h>

extern int snprintf(char *restrict, size_t, const char *restrict, ...)
    __attribute__((format(printf, 3, 4)));
extern int sscanf(const char *restrict, const char *restrict, ...)
    __attribute__((format(scanf, 2, 3)));

#define ROUND_TRIP(PRI, SCN, type, input)                                \
    do {                                                                \
        char buffer[128];                                                \
        type value = (input);                                            \
        type result = 0;                                                 \
        if (snprintf(buffer, sizeof buffer, "%" PRI, value) <= 0 ||       \
            sscanf(buffer, "%" SCN, &result) != 1 || result != value)     \
            return __LINE__;                                             \
    } while (0)

#define CHECK(suffix, signed_type, unsigned_type, minimum, maximum)               \
    do {                                                                          \
        ROUND_TRIP(PRId##suffix, SCNd##suffix, signed_type, minimum);               \
        ROUND_TRIP(PRIi##suffix, SCNi##suffix, signed_type, minimum);               \
        ROUND_TRIP(PRIo##suffix, SCNo##suffix, unsigned_type, maximum);             \
        ROUND_TRIP(PRIu##suffix, SCNu##suffix, unsigned_type, maximum);             \
        ROUND_TRIP(PRIx##suffix, SCNx##suffix, unsigned_type, maximum);             \
        ROUND_TRIP(PRIX##suffix, SCNx##suffix, unsigned_type, maximum);             \
        (void)sizeof(L"%" PRId##suffix);                                           \
    } while (0)

int main(void)
{
    CHECK(8, int8_t, uint8_t, INT8_MIN, UINT8_MAX);
    CHECK(16, int16_t, uint16_t, INT16_MIN, UINT16_MAX);
    CHECK(32, int32_t, uint32_t, INT32_MIN, UINT32_MAX);
    CHECK(64, int64_t, uint64_t, INT64_MIN, UINT64_MAX);
    CHECK(LEAST8, int_least8_t, uint_least8_t, INT_LEAST8_MIN, UINT_LEAST8_MAX);
    CHECK(LEAST16, int_least16_t, uint_least16_t, INT_LEAST16_MIN, UINT_LEAST16_MAX);
    CHECK(LEAST32, int_least32_t, uint_least32_t, INT_LEAST32_MIN, UINT_LEAST32_MAX);
    CHECK(LEAST64, int_least64_t, uint_least64_t, INT_LEAST64_MIN, UINT_LEAST64_MAX);
    CHECK(FAST8, int_fast8_t, uint_fast8_t, INT_FAST8_MIN, UINT_FAST8_MAX);
    CHECK(FAST16, int_fast16_t, uint_fast16_t, INT_FAST16_MIN, UINT_FAST16_MAX);
    CHECK(FAST32, int_fast32_t, uint_fast32_t, INT_FAST32_MIN, UINT_FAST32_MAX);
    CHECK(FAST64, int_fast64_t, uint_fast64_t, INT_FAST64_MIN, UINT_FAST64_MAX);
    CHECK(MAX, intmax_t, uintmax_t, INTMAX_MIN, UINTMAX_MAX);
    CHECK(PTR, intptr_t, uintptr_t, INTPTR_MIN, UINTPTR_MAX);
    return 0;
}
