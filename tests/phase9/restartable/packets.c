#include "fixture.h"
#include "model.c"

#include <sys/mman.h>

#ifndef OA_PHASE6_HOST
struct aux_entry { unsigned long type,value; };
extern const struct aux_entry *const __al_auxv;
#endif

struct stimulus { uint64_t mode,value; };
struct observed { uint64_t result,scalar,bytes,calls,digest,error,scenario,flags; };
_Static_assert(sizeof(struct stimulus)==16 && sizeof(struct observed)==64,"LP64 packet widths");

enum { SCENARIOS=14 };
struct guard { char *base; size_t page; };
struct array { unsigned char *start,*neighbor; };
struct context {
    enum operation primary;
    int utf8,sentinel,allow_error;
    unsigned flags;
    const struct guard *guards;
    struct observed *record;
};
static size_t linux_page_size(void)
{
#ifdef OA_PHASE6_HOST
    long size = sysconf(_SC_PAGESIZE);
    return size > 0 ? (size_t)size : 0;
#else
    for (const struct aux_entry *entry = __al_auxv; entry->type; ++entry)
        if (entry->type == 6)
            return entry->value;
    return 0;
#endif
}

static int map_guard(struct guard *guard, size_t page)
{
    long base = kernel_call(__NR_mmap, 0, (long)(3 * page), PROT_NONE,
                            MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (base < 0)
        return 0;
    if (kernel_call(__NR_mprotect, base + (long)page, (long)page, PROT_READ | PROT_WRITE, 0, 0, 0)) {
        (void)kernel_call(__NR_munmap, base, (long)(3 * page), 0, 0, 0, 0);
        return 0;
    }
    *guard = (struct guard){(char *)base, page};
    return 1;
}

static int unmap_guard(const struct guard *guard)
{
    return kernel_call(__NR_munmap, (long)guard->base, (long)(3 * guard->page),
                       0, 0, 0, 0) == 0;
}

static struct array place(const struct guard *guard,size_t count,int right)
{
    if (!count)
        return (struct array){(unsigned char *)guard->base,NULL};
    unsigned char *page=(unsigned char *)guard->base+guard->page;
    unsigned char *start=right ? page+guard->page-count : page;
    unsigned char *neighbor=right ? start-1 : start+count;
    *neighbor=BYTE_MARK;
    return (struct array){start,neighbor};
}

static void step(struct context *context,uint64_t result,uint64_t scalar,uint64_t bytes,
                 int error,unsigned initial)
{
    struct observed *record=context->record;
    record->result=context->primary==INITIAL ? initial : result;
    record->scalar=context->primary==INITIAL ? 0 : scalar;
    record->bytes=bytes;
    ++record->calls;
    const uint64_t values[]={result,scalar,bytes,(uint64_t)error,initial};
    for (size_t i=0;i<sizeof values/sizeof *values;++i)
        record->digest=record->digest*257+values[i];
    record->error=(uint64_t)error;
}

static int query(struct context *context,const struct state_box *state,int wanted)
{
    errno=context->sentinel;
    int actual=mbsinit(state ? &state->state : NULL)!=0;
    int error=errno;
    if (actual!=wanted)
        return 21;
    if (error!=context->sentinel)
        return 23;
    if (state && !state_guards(state))
        return 24;
    step(context,(uint64_t)actual,0,0,error,(unsigned)actual);
    return 0;
}

static int decode(struct context *context,enum operation operation,struct state_box *state,
                  struct logical_state *model,const unsigned char *bytes,size_t count,
                  int ignore_output,int null_input)
{
    static const unsigned char zero[]={0};
    struct decoded wanted=decode_bytes(model,null_input ? zero : bytes,null_input ? 1 : count,context->utf8);
    if (wanted.error && !context->allow_error)
        return 90;
    struct array input=place(&context->guards[0],null_input ? 0 : count,context->flags&1);
    volatile unsigned char *write=input.start;
    for (size_t i=0;!null_input && i<count;++i)
        write[i]=bytes[i];
    struct array output=place(&context->guards[1],sizeof(wchar_t),(context->flags>>1)&1);
    volatile wchar_t *wide=(wchar_t *)output.start;
    *wide=SCALAR_MARK;
    errno=context->sentinel;
    mbstate_t *actual_state=state ? &state->state : NULL;
    const char *source=null_input ? NULL : (const char *)input.start;
    size_t actual=operation==LENGTH ? public_length(source,count,actual_state) :
        mbrtowc(ignore_output ? NULL : (wchar_t *)output.start,source,count,actual_state);
    int error=errno;
    if (actual!=wanted.result)
        return 21;
    wchar_t scalar=operation==LENGTH || ignore_output || null_input || !wanted.wrote ?
                   SCALAR_MARK : (wchar_t)wanted.scalar;
    if (*wide!=scalar || *output.neighbor!=BYTE_MARK)
        return 22;
    if (error!=(wanted.error ? EILSEQ : context->sentinel))
        return 23;
    unsigned initial=2;
    if (state) {
        if (!state_guards(state))
            return 24;
        initial=mbsinit(&state->state)!=0;
        if ((int)initial!=wanted.initial || errno!=error || !state_guards(state))
            return 24;
    }
    if ((!null_input && !same_bytes(input.start,bytes,count)) ||
        (input.neighbor && *input.neighbor!=BYTE_MARK))
        return 25;
    step(context,actual,(uint32_t)*wide,0,error,initial);
    return 0;
}

static wchar_t wide_value(uint32_t bits)
{
    return (wchar_t)(bits<=INT32_MAX ? (int64_t)bits : (int64_t)bits-(INT64_C(1)<<32));
}

static int encode(struct context *context,struct state_box *state,uint32_t scalar,
                  int null_output,unsigned extra)
{
    unsigned char wanted[4];
    size_t width=scalar_bytes(null_output ? 0 : scalar,context->utf8,wanted);
    int invalid=width==(size_t)-1;
    if (invalid && !context->allow_error)
        return 90;
    size_t count=null_output || invalid ? 8 : width+extra;
    if (count>8)
        return 90;
    struct array output=place(&context->guards[1],count,(context->flags>>1)&1);
    volatile unsigned char *write=output.start;
    for (size_t i=0;i<count;++i)
        write[i]=BYTE_MARK;
    errno=context->sentinel;
    size_t actual=wcrtomb(null_output ? NULL : (char *)output.start,wide_value(scalar),
                         state ? &state->state : NULL);
    int error=errno;
    if (actual!=(null_output ? 1 : width))
        return 21;
    if (error!=(invalid ? EILSEQ : context->sentinel))
        return 23;
    uint64_t packed=0;
    for (size_t i=0;i<count;++i) {
        unsigned char expected=!null_output && !invalid && i<width ? wanted[i] : BYTE_MARK;
        if (output.start[i]!=expected)
            return 22;
        packed|=(uint64_t)output.start[i]<<(8*i);
    }
    if (*output.neighbor!=BYTE_MARK)
        return 22;
    unsigned initial=2;
    if (state) {
        if (!state_guards(state))
            return 24;
        initial=mbsinit(&state->state)!=0;
        if (!initial || errno!=error || !state_guards(state))
            return 24;
    }
    step(context,actual,scalar,packed,error,initial);
    return 0;
}

static uint32_t scalar_value(unsigned mode,uint64_t seed,int utf8)
{
    static const uint32_t boundary[]={0,0x7f,0x80,0x7ff,0x800,0xd7ff,0xe000,0xffff,0x10000,0x10ffff};
    if (!mode)
        return 'A';
    if (mode==1)
        return boundary[seed%(sizeof boundary/sizeof *boundary)];
    if (mode==11)
        return 0;
    uint32_t value=utf8 ? (uint32_t)(seed%0x110000) : (uint32_t)(seed&127);
    if (value>=0xd800 && value<=0xdfff)
        value+=0x800;
    if (mode==3 || mode==4 || mode==5 || mode==7 || mode==9)
        if (value<128)
            value+=128;
    return value;
}

static int observe(enum operation operation,struct stimulus input,const struct guard guards[2],
                   struct observed *output)
{
    unsigned mode=(unsigned)((input.mode&((UINT64_C(1)<<62)-1))%SCENARIOS);
    int utf8=(int)(input.value>>63) || mode==1 || mode==2 || mode==3 || mode==4 || mode==5 || mode==7 || mode==9;
    if (!setlocale(LC_CTYPE,utf8 ? "C.UTF-8" : "C"))
        return 90;
    *output=(struct observed){0,0,0,0,1,0,mode,(input.mode>>62)|((uint64_t)utf8<<2)};
    struct context context={operation,utf8,700+(int)((input.value>>32)&4095),0,
                            (unsigned)(input.mode>>62),guards,output};
    struct state_box a=fresh_state(),b=fresh_state();
    struct logical_state model={0},other={0};
    uint32_t scalar=scalar_value(mode,input.value,utf8);
    unsigned char bytes[8],second[4],ascii[]={'A'},q[]={'Q'};
    size_t width=scalar_bytes(scalar,utf8,bytes);
    if (width==(size_t)-1)
        return 90;
    int result=0;
    if (operation==INITIAL) {
        result=query(&context,&a,1);
        if (result || !mode)
            return result;
    }
    if (operation==ENCODE) {
        if (mode==8 || mode==10)
            return encode(&context,&a,mode==10 ? UINT32_MAX : scalar,1,0);
        if (mode==9)
            return encode(&context,NULL,scalar,0,0);
        result=encode(&context,&a,scalar,0,mode==0 || mode==12 ? 2 : 0);
        if (!result && (mode==4 || mode==5 || mode==13)) {
            b.state=a.state;
            result=encode(&context,&b,utf8 ? 0x1f642 : 'Q',0,0);
        }
        return result;
    }
    enum operation decoder=operation==LENGTH ? LENGTH : DECODE;
    switch (mode) {
    case 3:
        for (size_t i=0;!result && i<width;++i)
            result=decode(&context,decoder,&a,&model,bytes+i,1,0,0);
        break;
    case 4:
        result=decode(&context,decoder,&a,&model,bytes,1,0,0);
        if (!result) {
            b.state=a.state;
            other=model;
            result=decode(&context,decoder,&a,&model,bytes+1,width-1,0,0);
        }
        if (!result)
            result=query(&context,&b,0);
        if (!result)
            result=decode(&context,decoder,&b,&other,bytes+1,width-1,0,0);
        break;
    case 5: {
        unsigned char first[]={0xe2,0x82,0xac};
        size_t second_width=scalar_bytes(0x1f642,1,second);
        result=decode(&context,decoder,&a,&model,first,1,0,0);
        if (!result)
            result=decode(&context,decoder,&b,&other,second,1,0,0);
        if (!result)
            result=decode(&context,decoder,&a,&model,first+1,2,0,0);
        if (!result)
            result=query(&context,&b,0);
        if (!result)
            result=decode(&context,decoder,&b,&other,second+1,second_width-1,0,0);
        break;
    }
    case 6:
        result=decode(&context,decoder,&a,&model,bytes,0,0,0);
        if (!result)
            result=decode(&context,decoder,&a,&model,ascii,1,0,0);
        break;
    case 7:
        result=decode(&context,decoder,&a,&model,bytes,1,0,0);
        if (!result)
            result=decode(&context,decoder,&a,&model,bytes,0,0,0);
        if (!result)
            result=decode(&context,decoder,&a,&model,bytes+1,width-1,0,0);
        break;
    case 8:
        result=operation==INITIAL ? query(&context,NULL,1) :
            decode(&context,decoder,&a,&model,bytes,width,1,0);
        break;
    case 9:
        if (operation==INITIAL) {
            result=query(&context,NULL,1);
            if (!result)
                result=decode(&context,DECODE,&a,&model,bytes,width,0,0);
        } else {
            result=decode(&context,decoder,NULL,&model,bytes,1,0,0);
            if (!result)
                result=decode(&context,decoder==LENGTH ? DECODE : LENGTH,NULL,&other,q,1,0,0);
            if (!result)
                result=decode(&context,decoder,NULL,&model,bytes+1,width-1,0,0);
        }
        break;
    case 10:
        result=operation==INITIAL ? query(&context,NULL,1) :
            decode(&context,decoder,&a,&model,bytes,0,0,1);
        break;
    case 12:
        bytes[width]='Z';
        result=decode(&context,decoder,&a,&model,bytes,width+1,0,0);
        if (!result)
            result=decode(&context,decoder,&a,&model,bytes+width,1,0,0);
        break;
    case 13:
        b.state=a.state;
        result=decode(&context,decoder,&a,&model,bytes,width,0,0);
        if (!result)
            result=decode(&context,decoder,&b,&other,q,1,0,0);
        break;
    default:
        result=decode(&context,decoder,&a,&model,bytes,width,0,0);
        break;
    }
    return result;
}

static int contract(enum operation operation,const struct guard guards[2])
{
    static const struct { unsigned char bytes[6]; size_t count; } invalid[]={
        {{0x80},1},{{0xff},1},{{0xc0,0x80},2},{{0xe0,0x9f,0xbf},3},
        {{0xed,0xa0,0x80},3},{{0xf0,0x8f,0xbf,0xbf},4},
        {{0xf4,0x90,0x80,0x80},4},{{0xf5},1},{{0xe2,'A'},2},
    };
    static const uint32_t bad_scalars[]={0x80,0xd800,0xdfff,0x110000,UINT32_MAX};
    unsigned char ascii[]={'A'},lead[]={0xe2};
    for (int utf8=0;utf8<2;++utf8) {
        if (!setlocale(LC_CTYPE,utf8 ? "C.UTF-8" : "C"))
            return 90;
        for (unsigned flags=0;flags<4;++flags) {
            struct observed record={0,0,0,0,1,0,0,0};
            struct context context={operation,utf8,TEST_ERRNO,1,flags,guards,&record};
            if (operation==ENCODE) {
                for (size_t i=0;i<sizeof bad_scalars/sizeof *bad_scalars;++i) {
                    if (utf8 && bad_scalars[i]==0x80)
                        continue;
                    struct state_box state=fresh_state();
                    int result=encode(&context,&state,bad_scalars[i],0,0);
                    if (!result)
                        result=encode(&context,&state,'A',0,0);
                    if (result)
                        return result;
                }
            } else {
                enum operation decoder=operation==LENGTH ? LENGTH : DECODE;
                for (size_t i=0;i<sizeof invalid/sizeof *invalid;++i) {
                    struct state_box state=fresh_state();
                    struct logical_state model={0};
                    int result=decode(&context,decoder,&state,&model,invalid[i].bytes,invalid[i].count,0,0);
                    if (!result)
                        result=decode(&context,decoder,&state,&model,ascii,1,0,0);
                    if (result)
                        return result;
                }
                if (utf8) {
                    struct state_box state=fresh_state();
                    struct logical_state model={0};
                    int result=decode(&context,decoder,&state,&model,lead,1,0,0);
                    if (!result)
                        result=decode(&context,decoder,&state,&model,lead,0,0,1);
                    if (!result)
                        result=decode(&context,decoder,&state,&model,ascii,1,0,0);
                    if (result)
                        return result;
                }
            }
            if (operation==ENCODE) {
                int result=encode(&context,NULL,UINT32_MAX,0,0);
                if (!result)
                    result=encode(&context,NULL,'A',0,0);
                if (result)
                    return result;
            } else if (operation!=INITIAL) {
                struct logical_state model={0};
                unsigned char invalid_default[]={0x80};
                int result=decode(&context,operation,NULL,&model,invalid_default,1,0,0);
                if (!result)
                    result=decode(&context,operation,NULL,&model,ascii,1,0,0);
                if (result)
                    return result;
            }
        }
    }
    return 0;
}

static int read_row(struct stimulus *input)
{
    size_t done=0;
    while (done<sizeof *input) {
        long n=raw_read(STDIN_FILENO,(char *)input+done,sizeof *input-done);
        if (n==-EINTR)
            continue;
        if (n<0 || (!n && done))
            return -1;
        if (!n)
            return 0;
        done+=(size_t)n;
    }
    return 1;
}

static int write_row(const struct observed *output)
{
    size_t done=0;
    while (done<sizeof *output) {
        long n=raw_write(STDOUT_FILENO,(const char *)output+done,sizeof *output-done);
        if (n==-EINTR)
            continue;
        if (n<=0)
            return 0;
        done+=(size_t)n;
    }
    return 1;
}

static int directed(enum operation operation,const struct guard guards[2])
{
    static const uint64_t seeds[]={0,1,2,3,4,5,6,7,8,9,0x7f,0x80,0x7ff,0x800,0xd7ff,
                                  0xe000,0xffff,0x10000,0x10ffff,UINT64_MAX};
    for (unsigned mode=0;mode<SCENARIOS;++mode)
        for (uint64_t flags=0;flags<4;++flags)
            for (size_t i=0;i<sizeof seeds/sizeof *seeds;++i) {
                struct observed output;
                int result=observe(operation,(struct stimulus){mode|(flags<<62),seeds[i]},guards,&output);
                if (result)
                    return result;
            }
    return 0;
}

int main(int argc,char **argv)
{
    if (argc!=2 && (argc!=3 || (!same_text(argv[2],"guard") && !same_text(argv[2],"contract"))))
        return 90;
    enum operation operation=operation_from(argv[1]);
    if (operation==OPERATIONS)
        return 90;
    size_t page=linux_page_size();
    struct guard guards[2];
    if (page<1024 || page>SIZE_MAX/3 || page%_Alignof(wchar_t) || !map_guard(&guards[0],page))
        return 91;
    if (!map_guard(&guards[1],page)) {
        (void)unmap_guard(&guards[0]);
        return 91;
    }
    int result=0;
    if (argc==3) {
        result=same_text(argv[2],"guard") ? directed(operation,guards) : contract(operation,guards);
    } else {
        struct stimulus input;
        int got=0;
        while (!result && (got=read_row(&input))>0) {
            struct observed output;
            result=observe(operation,input,guards,&output);
            if (!result && !write_row(&output))
                result=93;
        }
        if (!result && got<0)
            result=93;
    }
    int first=unmap_guard(&guards[0]);
    return unmap_guard(&guards[1]) && first ? result : 94;
}
