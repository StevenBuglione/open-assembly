#ifndef COPY_BULK_MODEL_H
#define COPY_BULK_MODEL_H
#include <stddef.h>
#include <stdint.h>
#include <wchar.h>
void model_fill(wchar_t *, size_t, uint64_t, int);
void model_copy(unsigned char *, const unsigned char *, size_t);
int model_equal(const unsigned char *, const unsigned char *, size_t);
uint64_t model_digest(const unsigned char *, size_t);
#endif
