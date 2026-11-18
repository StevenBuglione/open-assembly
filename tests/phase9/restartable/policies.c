#include "fixture.h"

struct input { unsigned char bytes[6]; size_t count; };
static const struct input invalid[]={
    {{0x80},1},{{0xff},1},{{0xc0,0x80},2},{{0xed,0xa0,0x80},3},
    {{0xf4,0x90,0x80,0x80},4},{{0xf5,0x80,0x80,0x80},4},
    {{0xf8,0x88,0x80,0x80,0x80},5},{{0xe2,0x41},2},
};
static const wchar_t wide[]={0x80,0xdf80,0xd800,0x110000,-1};

int main(int argc,char **argv)
{
    if (argc!=3 || !setlocale(LC_CTYPE,argv[2]))
        return 90;
    enum operation operation=operation_from(argv[1]);
    if (operation==INITIAL || operation==OPERATIONS)
        return 90;
    size_t count=operation==ENCODE ? sizeof wide/sizeof *wide : sizeof invalid/sizeof *invalid;
    for (size_t i=0;i<count;++i) {
        struct state_box state=fresh_state();
        wchar_t scalar=SCALAR_MARK;
        unsigned char bytes[8]={BYTE_MARK,BYTE_MARK,BYTE_MARK,BYTE_MARK,BYTE_MARK,BYTE_MARK,BYTE_MARK,BYTE_MARK};
        errno=TEST_ERRNO;
        size_t result;
        if (operation==ENCODE)
            result=wcrtomb((char *)bytes,wide[i],&state.state);
        else if (operation==LENGTH)
            result=public_length((const char *)invalid[i].bytes,invalid[i].count,&state.state);
        else
            result=mbrtowc(&scalar,(const char *)invalid[i].bytes,invalid[i].count,&state.state);
        int error=errno;
        if (!state_guards(&state))
            return 91;
        uint64_t packed=0;
        for (unsigned j=0;j<8;++j)
            packed|=(uint64_t)bytes[j]<<(8*j);
        uint64_t record[8]={result,(uint64_t)error,(uint32_t)scalar,packed,i,
            operation==ENCODE ? (uint32_t)wide[i] : invalid[i].count,0,0};
        if (raw_write(STDOUT_FILENO,record,sizeof record)!=sizeof record)
            return 92;
    }
    return 0;
}
