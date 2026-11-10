; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: geteuid
; header: unistd.h
; prototype: uid_t geteuid(void)
; standard: POSIX.1-2024 XSH geteuid
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the effective user ID as an unsigned value. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global geteuid:function
extern __al_syscall:function

section .text.geteuid alloc exec nowrite progbits
geteuid:
    sub rsp, 8
    mov qword [rsp], 0
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 107                 ; __NR_geteuid
    call __al_syscall
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
