; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: execve
; header: unistd.h
; prototype: int execve(const char *path, char *const argv[], char *const envp[])
; standard: POSIX.1-2024 XSH execve
; deps: __errno_location
; errno: E2BIG, EACCES, EFAULT, EINVAL, EIO, EISDIR, ELIBBAD, ELOOP, EMFILE, ENAMETOOLONG, ENFILE, ENOENT, ENOEXEC, ENOMEM, ENOTDIR, EPERM, ETXTBSY
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-process-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Replace the process image with the given executable, argument vector, and environment vector.
; semantics: Use the supplied pathname without PATH search and pass both vectors to the Linux kernel.
; semantics: A successful replacement does not return. A returned error is -1 and sets errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global execve:function
extern __al_execve_raw:function
extern __al_syscall_result:function

section .text.execve alloc exec nowrite progbits
execve:
    sub rsp, 8
    call __al_execve_raw
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
