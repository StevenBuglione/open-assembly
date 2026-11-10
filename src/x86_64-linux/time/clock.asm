; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: clock
; header: time.h
; prototype: clock_t clock(void)
; standard: C17 7.27.2.1
; deps: __errno_location
; errno: EINVAL, EOVERFLOW
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-time64
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return elapsed process CPU time in microsecond units.
; semantics: Truncate fractional microseconds. Return clock_t -1 when the query fails or its result is unrepresentable.
; semantics: Preserve errno on success. Expose the kernel error or EOVERFLOW on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global clock:function
extern __al_clock_parts:function
extern __al_syscall_result:function

section .text.clock alloc exec nowrite progbits
clock:
    push rbp
    mov rbp, rsp
    mov edi, 2                    ; CLOCK_PROCESS_CPUTIME_ID
    call __al_clock_parts
    cmp rax, -4095
    jae .error
    imul rdx, 1000000             ; whole seconds to microseconds
    jo .overflow
    mov rsi, rdx
    mov rax, rcx
    xor edx, edx
    mov r9d, 1000
    div r9                        ; fractional microseconds
    add rax, rsi
    jo .overflow
    jmp .done
.overflow:
    mov rax, -75                  ; EOVERFLOW
.error:
    mov rdi, rax
    call __al_syscall_result
.done:
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
