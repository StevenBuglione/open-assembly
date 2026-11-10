; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: execv
; header: unistd.h
; prototype: int execv(const char *path, char *const argv[])
; standard: POSIX.1-2024 XSH execv
; deps: execve
; errno: E2BIG, EACCES, EFAULT, EINVAL, EIO, EISDIR, ELIBBAD, ELOOP, EMFILE, ENAMETOOLONG, ENFILE, ENOENT, ENOEXEC, ENOMEM, ENOTDIR, EPERM, ETXTBSY
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-exec-path
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Execute the explicit path with the supplied argument vector and current environ.
; semantics: A successful replacement does not return. A returned error is -1 and sets errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global execv:function
extern execve:function
extern environ:data

section .text.execv alloc exec nowrite progbits
execv:
    sub rsp, 8
    mov rdx, [rel environ]
    call execve
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
