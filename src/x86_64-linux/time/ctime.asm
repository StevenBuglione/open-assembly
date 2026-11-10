; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ctime
; header: time.h
; prototype: char *ctime(const time_t *timer)
; standard: C17 7.27.3.2
; deps: asctime, localtime_r
; errno: EINVAL, EOVERFLOW
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-civil-text
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Convert the calendar time to local broken-down time and use the C17 asctime representation.
; semantics: Use the shared static text result without overwriting the public localtime structure.
; semantics: Return null for an unrepresentable local time or text year.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ctime:function
extern localtime_r:function
extern asctime:function

section .text.ctime alloc exec nowrite progbits
ctime:
    sub rsp, 8
    lea rsi, [rel broken_down]
    call localtime_r
    test rax, rax
    jz .done
    mov rdi, rax
    call asctime
.done:
    add rsp, 8
    ret

section .bss.ctime alloc noexec write nobits align=8
broken_down: resb 56

section .note.GNU-stack noalloc noexec nowrite progbits
