; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: thrd_yield
; header: threads.h
; prototype: void thrd_yield(void)
; standard: C17 7.26.5.8
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Allow another runnable thread to proceed using Linux scheduler yield.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global thrd_yield:function
extern __al_syscall:function

section .text.thrd_yield alloc exec nowrite progbits
thrd_yield:
    sub rsp, 8
    mov qword [rsp], 0
    mov edi, 24                  ; __NR_sched_yield
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
