; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: _exit
; header: unistd.h
; prototype: _Noreturn void _exit(int status)
; standard: POSIX.1-2024 XSH _exit
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:linux-wait-status
; provenance: original
; narrow_args: edi:s32
; variadic: false
; noreturn: true
; semantics: Terminate the process immediately without invoking registered callbacks or flushing stdio streams.
; semantics: The low eight bits of status are available to the parent; the function never returns.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global _exit:function
extern __al_syscall:function

section .text._exit alloc exec nowrite progbits
_exit:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    movsxd rsi, edi
    mov [rsp + 8], rsi
    mov qword [rsp], 0
    mov edi, 231                   ; __NR_exit_group
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall

    mov edi, 60                    ; __NR_exit
    mov rsi, [rsp + 8]
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
