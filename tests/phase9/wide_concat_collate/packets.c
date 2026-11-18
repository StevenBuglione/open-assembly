#include "fixture.h"

#include <sys/mman.h>

#ifndef OA_PHASE6_HOST
struct aux_entry { unsigned long type,value; };
extern const struct aux_entry *const __al_auxv;
#endif

struct stimulus { uint64_t mode,value; };
struct observed {
    int64_t result;
    uint64_t scenario,source_units,destination_units,bound,utf8,contents,error;
};
_Static_assert(sizeof(struct stimulus)==16 && sizeof(struct observed)==64,"Linux LP64 packet widths");

enum { CAPACITY=160, CANARY=0x31415926, UNWRITTEN=0x52f19e34 };
static const unsigned scenarios[OPERATIONS]={10,12,10,10};
struct problem {
    wchar_t source[CAPACITY],destination[CAPACITY];
    size_t source_units,destination_units,bound;
    int null_destination;
};
struct guard { char *base; size_t page; };
struct array { wchar_t *start,*neighbor; };

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

static struct array place(const struct guard *guard, size_t units, int right)
{
    if (!units)
        return (struct array){(wchar_t *)guard->base, NULL};
    char *page = guard->base + guard->page;
    wchar_t *start = (wchar_t *)(page + (right ? guard->page - units * sizeof(wchar_t) : 0));
    wchar_t *neighbor = right ? start - 1 : start + units;
    *neighbor = CANARY;
    return (struct array){start, neighbor};
}

static uint32_t random_word(uint64_t *state)
{
    uint64_t value = (*state += UINT64_C(0x9e3779b97f4a7c15));
    value = (value ^ (value >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
    value = (value ^ (value >> 27)) * UINT64_C(0x94d049bb133111eb);
    return (uint32_t)(value ^ (value >> 31));
}

static wchar_t nonzero(uint64_t *state)
{
    static const wchar_t values[]={WCHAR_MIN,WCHAR_MAX,-1,1,0x100,0x10000,0x1000000};
    uint32_t word=random_word(state);
    unsigned index=word&15;
    return index<sizeof values/sizeof *values ? values[index] : element(word|1U);
}

static void copy_words(wchar_t *destination,const wchar_t *source,size_t count)
{
    volatile wchar_t *out=destination;
    for (size_t i=0;i<count;++i)
        out[i]=source[i];
}

static void pair(struct problem *problem,const wchar_t *source,size_t source_units,
                 const wchar_t *destination,size_t destination_units,size_t bound)
{
    problem->source_units=source_units;
    problem->destination_units=destination_units;
    problem->bound=bound;
    copy_words(problem->source,source,source_units);
    copy_words(problem->destination,destination,destination_units);
}

static void random_string(wchar_t *text,size_t length,uint64_t *state)
{
    for (size_t i=0;i<length;++i)
        text[i]=nonzero(state);
    text[length]=0;
}

static void append_problem(struct problem *problem,unsigned mode,uint64_t seed,int bounded)
{
    static const wchar_t source[]={WCHAR_MIN,0x100,0};
    static const wchar_t first[]={1,-1,WCHAR_MIN,0x100,0};
    if (!mode) {
        if (bounded) {
            static const wchar_t nonterminated[]={WCHAR_MIN,0x100};
            pair(problem,nonterminated,2,first,5,2);
            problem->destination[2]=0;
        } else {
            pair(problem,source,3,first,5,0);
            problem->destination[2]=0;
        }
        return;
    }
    uint64_t state=seed;
    size_t length=1+(size_t)(seed&63),prefix_length=1+(size_t)((seed>>8)&63);
    size_t bound=bounded ? 1+(size_t)((seed>>16)&63) : 0;
    int terminated=1;
    unsigned tail=0;
    if (bounded) {
        switch (mode) {
        case 1: length=0; bound=0; terminated=0; break;
        case 2: prefix_length=0; bound=1+(size_t)(seed%length); break;
        case 3: length=0; bound=SIZE_MAX; break;
        case 4: bound=length; terminated=0; break;
        case 5: bound=SIZE_MAX; break;
        case 6: length=bound+1; break;
        case 7: length=4; bound=(size_t)(seed%6); break;
        case 8: tail=2; bound=SIZE_MAX; break;
        case 9: length=0; prefix_length=0; bound=0; terminated=0; break;
        case 10: length=2; bound=SIZE_MAX; break;
        case 11: length=1; prefix_length=1; bound=1; terminated=0; break;
        }
    } else {
        switch (mode) {
        case 1: length=prefix_length=0; break;
        case 2: prefix_length=0; break;
        case 3: length=0; break;
        case 4: length=5; prefix_length=2; break;
        case 6: length=1; tail=2; break;
        case 7: tail=2; break;
        case 8: length=1U<<(seed%6); prefix_length=1U<<((seed>>8)%6); break;
        case 9: length=2; prefix_length=2; break;
        }
    }
    size_t take=bounded && bound<length ? bound : length;
    problem->bound=bound;
    problem->source_units=length+(unsigned)terminated;
    problem->destination_units=prefix_length+take+1+tail;
    if (problem->source_units)
        random_string(problem->source,length,&state);
    if (!terminated)
        problem->source_units=length;
    random_string(problem->destination,prefix_length,&state);
    volatile wchar_t *out=problem->destination;
    for (size_t i=prefix_length+1;i<problem->destination_units;++i)
        out[i]=UNWRITTEN;
    if ((!bounded && mode==4) || (bounded && mode==7)) {
        static const wchar_t raw[]={WCHAR_MIN,1,-1,WCHAR_MAX,0x1000000,0};
        copy_words(problem->source,raw,length);
    } else if ((!bounded && mode==9) || (bounded && mode==10)) {
        problem->source[0]=1;
        problem->source[1]=-1;
    } else if (bounded && mode==11) {
        problem->source[0]=WCHAR_MIN;
        problem->destination[0]=-1;
    }
    if ((!bounded && mode==6) || (bounded && mode==8)) {
        problem->source[problem->source_units++]=-1;
        problem->source[problem->source_units++]=WCHAR_MAX;
        problem->source[problem->source_units++]=0;
    }
}

static void collation_problem(struct problem *problem,unsigned mode,uint64_t seed)
{
    static const wchar_t empty[]={0},a[]={1,2,0},b[]={1,3,0};
    static const wchar_t high_a[]={WCHAR_MIN,-1,0},high_b[]={WCHAR_MAX,-1,0};
    static const wchar_t ordered_a[]={1,2,127,0},ordered_b[]={1,3,1,0};
    static const wchar_t tail_a[]={1,0,WCHAR_MIN,0},tail_b[]={1,0,WCHAR_MAX,0};
    switch (mode) {
    case 0: pair(problem,a,3,b,3,0); return;
    case 1: pair(problem,empty,1,empty,1,0); return;
    case 2: pair(problem,empty,1,a,3,0); return;
    case 3: pair(problem,a,3,empty,1,0); return;
    case 6: pair(problem,high_a,3,high_b,3,0); return;
    case 7: pair(problem,ordered_a,4,ordered_b,4,0); return;
    case 8: pair(problem,tail_a,4,tail_b,4,0); return;
    }
    uint64_t state=seed;
    size_t length=1+(size_t)(seed&63);
    problem->source_units=problem->destination_units=length+1;
    random_string(problem->source,length,&state);
    copy_words(problem->destination,problem->source,length+1);
    if (mode!=4) {
        problem->source[length-1]=seed&8 ? WCHAR_MIN : -1;
        problem->destination[length-1]=seed&8 ? WCHAR_MAX : 1;
        if (mode==9 && (seed&1)) {
            wchar_t value=problem->source[length-1];
            problem->source[length-1]=problem->destination[length-1];
            problem->destination[length-1]=value;
        }
    }
}

static void transform_problem(struct problem *problem,unsigned mode,uint64_t seed)
{
    uint64_t state=seed;
    size_t length=1+(size_t)(seed&63);
    if (mode==0)
        length=2;
    else if (mode==1)
        length=0;
    else if (mode==6)
        length=1;
    else if (mode==7)
        length=3;
    else if (mode==9)
        length=seed&1 ? 0 : 1;
    problem->source_units=length+1;
    random_string(problem->source,length,&state);
    if (!mode) {
        problem->source[0]=1;
        problem->source[1]=L'a';
    } else if (mode==6) {
        problem->source[0]=1;
        problem->source[2]=-1;
        problem->source[3]=0;
        problem->source_units=4;
    } else if (mode==7) {
        problem->source[0]=0x1f642;
        problem->source[1]=0x10000;
        problem->source[2]=0x10ffff;
    }
    problem->bound=length+1;
    problem->destination_units=length+1;
    if (mode==2 || mode==3) {
        problem->bound=problem->destination_units=0;
        problem->null_destination=mode==2;
    } else if (mode==4 || mode==9) {
        problem->bound=SIZE_MAX;
    } else if (mode==5) {
        problem->bound=problem->destination_units=length+4;
    }
    volatile wchar_t *destination=problem->destination;
    for (size_t i=0;i<problem->destination_units;++i)
        destination[i]=UNWRITTEN;
}

static size_t length(const volatile wchar_t *text,size_t units)
{
    for (size_t i=0;i<units;++i)
        if (!text[i])
            return i;
    return SIZE_MAX;
}

static uint64_t digest(uint64_t value,const wchar_t *text,size_t units)
{
    for (size_t i=0;i<units;++i)
        value=value*257+(uint32_t)text[i];
    return value*257+units;
}

static int observe(enum operation operation,struct stimulus input,const struct guard guards[2],
                   struct observed *output)
{
    unsigned mode=(unsigned)((input.mode&((UINT64_C(1)<<62)-1))%scenarios[operation]);
    int utf8=(int)(input.value>>63);
    if (!setlocale(LC_ALL,utf8 ? "C.UTF-8" : "C"))
        return 90;
    struct problem problem;
    problem.source_units=problem.destination_units=problem.bound=0;
    problem.null_destination=0;
    if (operation==CAT || operation==NCAT)
        append_problem(&problem,mode,input.value,operation==NCAT);
    else if (operation==COLL)
        collation_problem(&problem,mode,input.value);
    else
        transform_problem(&problem,mode,input.value);
    if (problem.source_units>CAPACITY || problem.destination_units>CAPACITY)
        return 92;
    struct array source=place(&guards[0],problem.source_units,(input.mode>>62)&1);
    struct array destination=place(&guards[1],problem.destination_units,input.mode>>63);
    copy_words(source.start,problem.source,problem.source_units);
    copy_words(destination.start,problem.destination,problem.destination_units);
    wchar_t expected[CAPACITY];
    copy_words(expected,problem.destination,problem.destination_units);
    size_t source_length=SIZE_MAX,destination_length=0,take=0;
    int comparison=0;
    if (operation==NCAT) {
        while (take<problem.bound && take<problem.source_units && problem.source[take])
            ++take;
        if (take<problem.bound && take==problem.source_units)
            return 92;
    } else {
        source_length=length(problem.source,problem.source_units);
        if (source_length==SIZE_MAX)
            return 92;
        take=source_length;
    }
    if (operation==CAT || operation==NCAT) {
        destination_length=length(problem.destination,problem.destination_units);
        if (destination_length==SIZE_MAX || take>=problem.destination_units-destination_length)
            return 92;
        for (size_t i=0;i<take;++i)
            expected[destination_length+i]=problem.source[i];
        expected[destination_length+take]=0;
    } else if (operation==COLL) {
        destination_length=length(problem.destination,problem.destination_units);
        if (destination_length==SIZE_MAX)
            return 92;
        size_t count=source_length<destination_length ? source_length : destination_length;
        for (size_t i=0;i<=count;++i) {
            wchar_t a=problem.source[i],b=problem.destination[i];
            if (a!=b) {
                comparison=(a>b)-(a<b);
                break;
            }
        }
    } else if (problem.bound>source_length) {
        copy_words(expected,problem.source,source_length+1);
    }
    int sentinel=700+(int)((input.value>>32)&4095);
    errno=sentinel;
    wchar_t *returned=destination.start;
    int order=0;
    size_t size=0;
    switch (operation) {
    case CAT: returned=wcscat(destination.start,source.start); break;
    case NCAT: returned=wcsncat(destination.start,source.start,problem.bound); break;
    case COLL: order=wcscoll(source.start,destination.start); break;
    default: size=wcsxfrm(problem.null_destination ? NULL : destination.start,source.start,problem.bound); break;
    }
    int error=errno;
    if (operation==COLL) {
        if ((order>0)-(order<0)!=comparison)
            return 21;
    } else if (operation==XFRM) {
        if (size!=source_length)
            return 21;
    } else if (returned!=destination.start) {
        return 21;
    }
    if (error!=sentinel)
        return 22;
    if (!same_wide(source.start,problem.source,problem.source_units) ||
        !same_wide(destination.start,expected,problem.destination_units) ||
        (source.neighbor && *source.neighbor!=CANARY) ||
        (destination.neighbor && *destination.neighbor!=CANARY))
        return 23;
    int64_t result=0;
    if (operation==COLL)
        result=comparison;
    else if (operation==XFRM)
        result=(int64_t)size;
    uint64_t contents=digest(1,source.start,problem.source_units);
    contents=digest(contents,destination.start,problem.destination_units);
    *output=(struct observed){result,mode,problem.source_units,problem.destination_units,problem.bound,
                              (uint64_t)utf8,contents,(uint64_t)error};
    return 0;
}

static int read_row(struct stimulus *input)
{
    size_t done = 0;
    while (done < sizeof *input) {
        long n = raw_read(STDIN_FILENO, (char *)input + done, sizeof *input - done);
        if (n == -EINTR)
            continue;
        if (n < 0 || (!n && done))
            return -1;
        if (!n)
            return 0;
        done += (size_t)n;
    }
    return 1;
}

static int write_row(const struct observed *output)
{
    size_t done = 0;
    while (done < sizeof *output) {
        long n = raw_write(STDOUT_FILENO, (const char *)output + done, sizeof *output - done);
        if (n == -EINTR)
            continue;
        if (n <= 0)
            return 0;
        done += (size_t)n;
    }
    return 1;
}

static int directed(enum operation operation, const struct guard guards[2])
{
    static const uint64_t seeds[] = {
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 31, 63, 127,
        UINT64_C(0x8000000000000001), UINT64_C(0x800000000000007f),
    };
    for (unsigned mode = 0; mode < scenarios[operation]; ++mode) {
        for (uint64_t sides = 0; sides < 4; ++sides) {
            for (size_t i = 0; i < sizeof seeds / sizeof *seeds; ++i) {
                struct stimulus input = {mode | (sides << 62), seeds[i]};
                struct observed output;
                int result = observe(operation, input, guards, &output);
                if (result)
                    return result;
            }
        }
    }
    return 0;
}

static int short_keys(const struct guard guards[2])
{
    static const wchar_t original[]={WCHAR_MIN,1,-1,WCHAR_MAX,0};
    for (int utf8=0;utf8<2;++utf8) {
        if (!setlocale(LC_ALL,utf8 ? "C.UTF-8" : "C"))
            return 90;
        for (unsigned flags=0;flags<4;++flags) {
            for (size_t n=1;n<=4;++n) {
                struct array source=place(&guards[0],5,flags&1);
                struct array destination=place(&guards[1],n,flags>>1);
                copy_words(source.start,original,5);
                volatile wchar_t *words=destination.start;
                for (size_t i=0;i<n;++i)
                    words[i]=UNWRITTEN;
                errno=TEST_ERRNO;
                size_t result=wcsxfrm(destination.start,source.start,n);
                int error=errno;
                if (result!=4)
                    return 21;
                if (error!=TEST_ERRNO)
                    return 22;
                for (size_t i=0;i<n;++i)
                    if (words[i]!=UNWRITTEN)
                        return 23;
                if (!same_wide(source.start,original,5) || *source.neighbor!=CANARY ||
                    *destination.neighbor!=CANARY)
                    return 23;
            }
        }
    }
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2 && (argc != 3 ||
        (!same_text(argv[2], "guard") && !same_text(argv[2], "contract"))))
        return 90;
    enum operation operation = operation_from(argv[1]);
    if (operation == OPERATIONS)
        return 90;
    size_t page = linux_page_size();
    struct guard guards[2];
    if (page <= CAPACITY * sizeof(wchar_t) || page > SIZE_MAX / 3 ||
        page % _Alignof(wchar_t) || !map_guard(&guards[0], page))
        return 91;
    if (!map_guard(&guards[1], page)) {
        (void)unmap_guard(&guards[0]);
        return 91;
    }
    int result = 0;
    if (argc == 3) {
        if (same_text(argv[2], "guard"))
            result = directed(operation, guards);
        else
            result = operation == XFRM ? short_keys(guards) : 90;
    } else {
        struct stimulus input;
        int got = 0;
        while (!result && (got = read_row(&input)) > 0) {
            struct observed output;
            result = observe(operation, input, guards, &output);
            if (!result && !write_row(&output))
                result = 93;
        }
        if (!result && got < 0)
            result = 93;
    }
    int cleaned_first = unmap_guard(&guards[0]);
    return unmap_guard(&guards[1]) && cleaned_first ? result : 94;
}
