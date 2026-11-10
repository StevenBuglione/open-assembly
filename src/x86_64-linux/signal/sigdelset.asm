; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sigdelset
; header: signal.h
; prototype: int sigdelset(sigset_t *set, int sig)
; standard: POSIX.1-2024 XSH sigdelset
; deps: __errno_location
; errno: EINVAL
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-signal-abi
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Remove the signal bit identified by an integer from 1 through 64.
; semantics: Modify only the selected signal bit and return zero.
; semantics: Preserve errno on success. Invalid signal numbers return -1 and set EINVAL.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sigdelset:function
extern __al_syscall_result:function

section .text.sigdelset alloc exec nowrite progbits
sigdelset:
    movsxd rsi, esi
    cmp esi, 1
    jl .invalid
    cmp esi, 64
    ja .invalid
    lea ecx, [rsi - 1]
    mov eax, 1
    shl rax, cl
    not rax
    and [rdi], rax
    xor eax, eax
    ret
.invalid:
    push rbp
    mov rbp, rsp
    mov rdi, -22                  ; EINVAL
    call __al_syscall_result
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
