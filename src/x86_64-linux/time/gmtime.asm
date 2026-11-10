; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: gmtime
; header: time.h
; prototype: struct tm *gmtime(const time_t *timer)
; standard: C17 7.27.3.3
; deps: gmtime_r
; errno: EOVERFLOW
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:gregorian-utc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Convert time to UTC with the same fields and range checks as gmtime_r.
; semantics: Return a pointer to library-owned static storage that can be overwritten by a later call.
; semantics: Return null and set EOVERFLOW when tm_year cannot represent the year.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global gmtime:function
extern gmtime_r:function

section .text.gmtime alloc exec nowrite progbits
gmtime:
    push rbp
    mov rbp, rsp
    lea rsi, [rel utc_result]
    call gmtime_r
    pop rbp
    ret

section .bss.gmtime alloc noexec write nobits align=8
utc_result:
    resb 56

section .note.GNU-stack noalloc noexec nowrite progbits
