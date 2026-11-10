; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mkdir
; header: sys/stat.h
; prototype: int mkdir(const char *path, mode_t mode)
; standard: POSIX.1-2024 XSH mkdir
; deps: __errno_location
; errno: EACCES, EDQUOT, EEXIST, EFAULT, EINVAL, ELOOP, EMLINK, ENAMETOOLONG, ENOENT, ENOMEM, ENOSPC, ENOTDIR, EPERM, EROFS
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: esi:u32
; variadic: false
; semantics: Create a directory using the requested mode and the process umask.
; semantics: Return zero on success.
; semantics: Preserve errno on success. Translate a Linux kernel error to -1 and thread-local errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mkdir:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.mkdir alloc exec nowrite progbits
mkdir:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov edx, esi                   ; unsigned mode
    mov rsi, rdi                   ; path
    mov edi, 83                    ; __NR_mkdir
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
