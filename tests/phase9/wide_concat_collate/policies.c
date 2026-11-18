#include "fixture.h"

enum { MARK = 0x31415926 };

int main(int argc, char **argv)
{
    if (argc != 3 || !setlocale(LC_ALL,argv[2]))
        return 90;
    enum operation operation=operation_from(argv[1]);
    if (operation == COLL) {
        static const wchar_t pairs[][2] = {
            {1,2},{0x10000,0x100},{WCHAR_MIN,WCHAR_MAX},{-1,WCHAR_MAX},
            {WCHAR_MIN,-1},{INT32_MIN+0x5a,INT32_MIN+0x1005a},
            {WCHAR_MAX,WCHAR_MIN},{1,1},
        };
        for (size_t i=0;i<sizeof pairs/sizeof *pairs;++i) {
            wchar_t a[]={pairs[i][0],0},b[]={pairs[i][1],0};
            errno=TEST_ERRNO;
            int value=wcscoll(a,b);
            int error=errno;
            int64_t output[8]={value,(value>0)-(value<0),error,(int64_t)i,pairs[i][0],pairs[i][1],0,0};
            if (raw_write(STDOUT_FILENO,output,sizeof output)!=sizeof output)
                return 91;
        }
    } else if (operation == XFRM) {
        static const size_t counts[]={0,1,2,3,4,SIZE_MAX};
        const wchar_t source[]={0x1f642,L'a',0};
        size_t query=wcsxfrm(NULL,source,0);
        if (query>5)
            return 92;
        for (size_t i=0;i<sizeof counts/sizeof *counts;++i) {
            struct { uint64_t result,bound; int64_t error,index; wchar_t words[8]; } output;
            _Static_assert(sizeof output==64,"raw policy width");
            volatile wchar_t *words=output.words;
            for (size_t j=0;j<8;++j)
                words[j]=MARK;
            errno=TEST_ERRNO;
            output.result=wcsxfrm(counts[i] ? output.words+1 : NULL,source,counts[i]);
            output.error=errno;
            output.bound=counts[i];
            output.index=(int64_t)i;
            if (output.words[0]!=MARK || output.words[7]!=MARK)
                return 93;
            if (raw_write(STDOUT_FILENO,&output,sizeof output)!=sizeof output)
                return 91;
        }
    } else {
        return 90;
    }
    return 0;
}
