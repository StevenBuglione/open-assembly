; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sigismember
; header: signal.h
; prototype: int sigismember(const sigset_t *set, int sig)
; standard: POSIX.1-2024 XSH sigismember
; deps: __errno_location
; errno: EINVAL
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-signal-abi
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Query the signal bit identified by an integer from 1 through 64.
; semantics: Return one for present or zero for absent without changing the mask.
; semantics: Preserve errno on success. Invalid signal numbers return -1 and set EINVAL.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sigismember:function
extern __al_syscall_result:function

section .text.sigismember alloc exec nowrite progbits
sigismember:
    movsxd rsi, esi
    cmp esi, 1
    jl .invalid
    cmp esi, 64
    ja .invalid
    lea ecx, [rsi - 1]
    mov eax, 1
    shl rax, cl
    test [rdi], rax
    jz .absent
    mov eax, 1
    ret
.absent:
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
