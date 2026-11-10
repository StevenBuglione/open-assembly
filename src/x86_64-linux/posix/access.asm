; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: access
; header: unistd.h
; prototype: int access(const char *path, int mode)
; standard: POSIX.1-2024 XSH access
; deps: __errno_location
; errno: EACCES, EFAULT, EINVAL, EIO, ELOOP, ENAMETOOLONG, ENOENT, ENOMEM, ENOTDIR, EPERM, EROFS
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Check existence or requested permissions using the real process IDs.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global access:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.access alloc exec nowrite progbits
access:
    sub rsp, 8
    mov qword [rsp], 0
    movsxd rdx, esi
    mov rsi, rdi
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 21                  ; __NR_access
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
