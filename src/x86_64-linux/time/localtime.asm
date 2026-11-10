; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: localtime
; header: time.h
; prototype: struct tm *localtime(const time_t *timep)
; standard: C17 7.27.3.4
; deps: localtime_r
; errno: EOVERFLOW
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Convert using the current timezone and publish the result in static broken-down time storage.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global localtime:function
extern localtime_r:function

section .text.localtime alloc exec nowrite progbits
localtime:
    sub rsp, 8
    lea rsi, [rel local_result]
    call localtime_r
    add rsp, 8
    ret

section .bss.localtime alloc noexec write nobits align=8
local_result: resb 56

section .note.GNU-stack noalloc noexec nowrite progbits
