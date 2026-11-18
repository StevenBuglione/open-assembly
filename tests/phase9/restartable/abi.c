#include "fixture.h"

extern unsigned phase2_abi_probe_result(uintptr_t,const uint64_t[6],uint64_t[2]);

static int probe(uintptr_t function,uint64_t args[6],size_t expected,int boolean)
{
    uint64_t result[2]={0,0};
    errno=TEST_ERRNO;
    if (phase2_abi_probe_result(function,args,result))
        return 11;
    if (boolean)
        result[0]=(uint32_t)result[0]!=0;
    return result[0]==expected && errno==TEST_ERRNO ? 0 : 12;
}

int main(int argc,char **argv)
{
    if (argc!=2 || !setlocale(LC_CTYPE,"C.UTF-8"))
        return 90;
    enum operation operation=operation_from(argv[1]);
    if (operation==OPERATIONS)
        return 90;
    struct state_box state=fresh_state();
    struct wide_box wide={UINT64_C(0x745be813216ea9c5),SCALAR_MARK,UINT64_C(0x85613bdae4c591af)};
    char bytes[8]={'Z','Z','Z','Z','Z','Z','Z','Z'};
    const char ascii[]={'A'};
    const char lead[]={(char)0xe2},tail[]={(char)0x82,(char)0xac};
    uint64_t args[6]={0,0,0,0,UINT64_C(0x458dfa675adeb39c),UINT64_C(0x93871c5436f71a28)};
    int result=0;
    if (operation==LENGTH || operation==DECODE) {
        uintptr_t function=operation==LENGTH ? (uintptr_t)mbrlen : (uintptr_t)mbrtowc;
        unsigned source=operation==LENGTH ? 0 : 1;
        if (operation==DECODE)
            args[0]=(uintptr_t)&wide.value;
        args[source]=(uintptr_t)ascii;
        args[source+1]=1;
        args[source+2]=(uintptr_t)&state.state;
        result=probe(function,args,1,0);
        if (!result && operation==DECODE && wide.value!='A')
            result=13;
        wide.value=SCALAR_MARK;
        args[source]=(uintptr_t)lead;
        if (!result)
            result=probe(function,args,(size_t)-2,0);
        if (!result && (wide.value!=SCALAR_MARK || mbsinit(&state.state)))
            result=13;
        args[source]=(uintptr_t)tail;
        args[source+1]=2;
        if (!result)
            result=probe(function,args,2,0);
        if (!result && (!mbsinit(&state.state) || (operation==DECODE && wide.value!=0x20ac)))
            result=13;
        args[source]=0;
        args[source+1]=0;
        wchar_t previous=wide.value;
        if (!result)
            result=probe(function,args,0,0);
        if (!result && wide.value!=previous)
            result=13;
    } else if (operation==ENCODE) {
        args[0]=(uintptr_t)bytes;
        args[1]=UINT64_C(0xa48319ed00000041);
        args[2]=(uintptr_t)&state.state;
        result=probe((uintptr_t)wcrtomb,args,1,0);
        if (!result && (bytes[0]!='A' || bytes[1]!='Z'))
            result=13;
        args[1]=UINT64_C(0x8d31975c0001f642);
        if (!result)
            result=probe((uintptr_t)wcrtomb,args,4,0);
        static const unsigned char expected[]={0xf0,0x9f,0x99,0x82,'Z','Z','Z','Z'};
        if (!result && !same_bytes((unsigned char *)bytes,expected,8))
            result=13;
        args[0]=0;
        args[1]=UINT64_C(0x93a1bf26ffffffff);
        if (!result)
            result=probe((uintptr_t)wcrtomb,args,1,0);
    } else {
        args[0]=(uintptr_t)&state.state;
        result=probe((uintptr_t)mbsinit,args,1,1);
        args[0]=0;
        if (!result)
            result=probe((uintptr_t)mbsinit,args,1,1);
        wchar_t value=SCALAR_MARK;
        if (!result && (mbrtowc(&value,lead,1,&state.state)!=(size_t)-2 || value!=SCALAR_MARK))
            result=13;
        args[0]=(uintptr_t)&state.state;
        if (!result)
            result=probe((uintptr_t)mbsinit,args,0,1);
        if (!result && (mbrtowc(&value,tail,2,&state.state)!=2 || value!=0x20ac))
            result=13;
        if (!result)
            result=probe((uintptr_t)mbsinit,args,1,1);
    }
    if (!result && (!state_guards(&state) || wide.before!=UINT64_C(0x745be813216ea9c5) ||
                    wide.after!=UINT64_C(0x85613bdae4c591af)))
        result=13;
    return result;
}
