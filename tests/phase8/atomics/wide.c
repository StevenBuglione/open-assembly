#include <compiler_rt.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>

typedef unsigned __int128 wide;
#define WIDE(hi, lo) (((wide)UINT64_C(hi) << 64) | UINT64_C(lo))

static const wide old_value = WIDE(0x4370a5119af03d28, 0xffedff47d991b87c);
static const wide replacement = WIDE(0x19c38f24be7dc45e, 0x83d91c34ffa61341);

static int simple(const char *mode)
{
    _Alignas(16) wide object = old_value;
    errno = EDOM;
    if (!strcmp(mode, "load16"))
        return __al_abi_atomic_load_16(&object, __ATOMIC_ACQUIRE) == old_value &&
               object == old_value && errno == EDOM ? 0 : 21;
    if (!strcmp(mode, "store16")) {
        __al_abi_atomic_store_16(&object, replacement, __ATOMIC_RELEASE);
        return object == replacement && errno == EDOM ? 0 : 22;
    }
    if (!strcmp(mode, "exchange16"))
        return __al_abi_atomic_exchange_16(&object, replacement, __ATOMIC_SEQ_CST) == old_value &&
               object == replacement && errno == EDOM ? 0 : 23;
    if (strcmp(mode, "compare16"))
        return 91;
    wide expected = replacement;
    if (__al_abi_atomic_compare_exchange_16(&object, &expected, replacement, __ATOMIC_SEQ_CST, __ATOMIC_ACQUIRE) ||
        expected != old_value || object != old_value || errno != EDOM)
        return 24;
    return __al_abi_atomic_compare_exchange_16(&object, &expected, replacement, __ATOMIC_SEQ_CST, __ATOMIC_ACQUIRE) &&
           expected == old_value && object == replacement && errno == EDOM ? 0 : 25;
}

typedef wide (*fetch)(volatile void *, wide, int);

static int arithmetic(const char *mode)
{
    const char *const names[] = {"add16", "sub16", "and16", "or16", "xor16", "nand16"};
    const fetch operations[] = {
        __al_abi_atomic_fetch_add_16, __al_abi_atomic_fetch_sub_16, __al_abi_atomic_fetch_and_16,
        __al_abi_atomic_fetch_or_16, __al_abi_atomic_fetch_xor_16, __al_abi_atomic_fetch_nand_16,
    };
    const wide input[][2] = {
        {old_value, replacement}, {(wide)-1, 1}, {0, 1}, {((wide)1 << 64) - 1, 2},
        {((wide)1 << 64), 1},
    };
    for (size_t index = 0; index < sizeof names / sizeof names[0]; ++index) {
        if (strcmp(mode, names[index]))
            continue;
        for (size_t i = 0; i < sizeof input / sizeof input[0]; ++i) {
            _Alignas(16) wide object = input[i][0];
            wide operand = input[i][1];
            const wide answers[] = {object + operand, object - operand, object & operand,
                                    object | operand, object ^ operand, ~(object & operand)};
            errno = EDOM;
            if (operations[index](&object, operand, __ATOMIC_RELAXED) != input[i][0] ||
                object != answers[index] || errno != EDOM)
                return 30 + (int)index;
        }
        return 0;
    }
    return 91;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    int direct = simple(argv[1]);
    return direct == 91 ? arithmetic(argv[1]) : direct;
}
