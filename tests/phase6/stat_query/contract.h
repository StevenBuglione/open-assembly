#ifndef OA_STAT_QUERY_CONTRACT_H
#define OA_STAT_QUERY_CONTRACT_H

#include "../stat_identity/fixture.h"

enum { QUERY_FSTAT = 5, QUERY_FSTATAT = 262 };
_Static_assert(QUERY_FSTAT == __NR_fstat && QUERY_FSTATAT == __NR_newfstatat,
               "documented x86-64 Linux selector values");

long __al_stat_query(int selector, long descriptor, const char *path, long flags,
                     struct stat *result);

#endif
