#include "fixture.h"

extern unsigned phase2_abi_probe_result(uintptr_t,const uint64_t[6],uint64_t[2]);

enum { WORDS=16, MARK=0x31415926 };

static int probe(uintptr_t function,const uint64_t args[6],uint64_t expected,int comparison)
{
    uint64_t result[2]={0,0};
    errno=TEST_ERRNO;
    if (phase2_abi_probe_result(function,args,result))
        return 11;
    if (comparison) {
        uint32_t low=(uint32_t)result[0];
        result[0]=low ? (low&UINT32_C(0x80000000) ? UINT64_MAX : 1) : 0;
    }
    return result[0]==expected && errno==TEST_ERRNO ? 0 : 12;
}

int main(int argc,char **argv)
{
    if (argc!=2 || !setlocale(LC_ALL,"C"))
        return 90;
    enum operation operation=operation_from(argv[1]);
    if (operation==OPERATIONS)
        return 90;
    static const wchar_t original_a[WORDS]={MARK,WCHAR_MIN,1,-1,WCHAR_MAX,0,1,-1,0,MARK,MARK,MARK,MARK,MARK,MARK,MARK};
    static const wchar_t original_b[WORDS]={MARK,1,-1,0,MARK,MARK,MARK,MARK,MARK,MARK,MARK,MARK,MARK,MARK,MARK,MARK};
    wchar_t a[WORDS],b[WORDS],expected[WORDS];
    for (size_t i=0;i<WORDS;++i) {
        a[i]=original_a[i];
        b[i]=expected[i]=original_b[i];
    }
    uint64_t args[6]={(uintptr_t)(b+1),(uintptr_t)(a+1),UINT64_C(0xa83b7fd9277e310b),
        UINT64_C(0x79bd3aa501c43c85),UINT64_C(0xa55dce7b2f3a7162),UINT64_C(0x6e76439d2a6b14b5)};
    int result=0;
    if (operation==CAT || operation==NCAT) {
        uintptr_t function=operation==CAT ? (uintptr_t)wcscat : (uintptr_t)wcsncat;
        size_t take=operation==CAT ? 4 : 2;
        args[2]=take;
        for (size_t i=0;i<take;++i)
            expected[3+i]=original_a[1+i];
        expected[3+take]=0;
        result=probe(function,args,(uintptr_t)(b+1),0);
        if (!result && !same_wide(b,expected,WORDS))
            result=13;
        if (!result && operation==NCAT) {
            args[2]=0;
            result=probe(function,args,(uintptr_t)(b+1),0);
            for (size_t i=0;i<WORDS;++i)
                b[i]=expected[i]=original_b[i];
            for (size_t i=0;i<4;++i)
                expected[3+i]=original_a[1+i];
            expected[7]=0;
            args[2]=SIZE_MAX;
            if (!result)
                result=probe(function,args,(uintptr_t)(b+1),0);
        }
    } else if (operation==COLL) {
        args[0]=(uintptr_t)(a+1);
        args[1]=(uintptr_t)(b+1);
        result=probe((uintptr_t)wcscoll,args,UINT64_MAX,1);
        args[0]=(uintptr_t)(b+1);
        args[1]=(uintptr_t)(a+1);
        if (!result)
            result=probe((uintptr_t)wcscoll,args,1,1);
        args[0]=args[1];
        if (!result)
            result=probe((uintptr_t)wcscoll,args,0,1);
    } else {
        args[2]=5;
        for (size_t i=0;i<5;++i)
            expected[1+i]=original_a[1+i];
        result=probe((uintptr_t)wcsxfrm,args,4,0);
        if (!result && !same_wide(b,expected,WORDS))
            result=13;
        args[0]=0;
        args[2]=0;
        if (!result)
            result=probe((uintptr_t)wcsxfrm,args,4,0);
        args[0]=(uintptr_t)(b+1);
        args[2]=SIZE_MAX;
        if (!result)
            result=probe((uintptr_t)wcsxfrm,args,4,0);
        for (size_t i=0;i<WORDS;++i)
            b[i]=expected[i]=original_b[i];
        args[2]=4;
        if (!result)
            result=probe((uintptr_t)wcsxfrm,args,4,0);
    }
    if (!result && (!same_wide(a,original_a,WORDS) || !same_wide(b,expected,WORDS)))
        result=13;
    return result;
}
