; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fputs_unlocked
; header: stdio.h
; prototype: int fputs_unlocked(const char *restrict s, FILE *restrict stream)
; standard: Extension ABI fputs_unlocked
; deps: strlen
; errno: EBADF, EIO
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-busybox-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Write the string without its terminating NUL. Return a nonnegative value, or EOF on failure.
; semantics: Do not acquire the stdio lock. The caller is responsible for synchronization.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fputs_unlocked:function
extern strlen:function
extern __al_stream_write:function

section .text.fputs_unlocked alloc exec nowrite progbits
fputs_unlocked:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rsi
    mov r12, rdi
    call strlen
    mov rdi, rbx
    mov rsi, r12
    mov rdx, rax
    call __al_stream_write
    xor eax, eax
    test rdx, rdx
    jz .done
    mov eax, -1
.done:
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
