; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: umask
; header: sys/stat.h
; prototype: mode_t umask(mode_t mask)
; standard: POSIX.1-2024 XSH umask
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-busybox-abi
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Set the Linux process file-creation mask from the permission bits in mask.
; semantics: Return the previous mask and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global umask:function
extern __al_syscall:function

section .text.umask alloc exec nowrite progbits
umask:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov esi, edi                   ; unsigned mode mask
    mov edi, 95                    ; __NR_umask
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
