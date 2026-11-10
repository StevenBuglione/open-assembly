; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: creat
; header: fcntl.h
; prototype: int creat(const char *path, mode_t mode)
; standard: POSIX.1-2024 XSH creat
; deps: open
; errno: EACCES, EBADF, EDQUOT, EEXIST, EFAULT, EINTR, EINVAL, EISDIR, ELOOP, EMFILE, ENAMETOOLONG, ENFILE, ENODEV, ENOENT, ENOMEM, ENOSPC, ENOTDIR, ENXIO, EOVERFLOW, EPERM, EROFS, ETXTBSY
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: esi:u32
; variadic: false
; semantics: Create or truncate a writable file with flags O_WRONLY, O_CREAT, and O_TRUNC.
; semantics: Use mode and the process umask for a newly created file.
; semantics: Preserve errno on success. Translate a Linux kernel error to -1 and thread-local errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global creat:function
extern open:function

section .text.creat alloc exec nowrite progbits
creat:
    push rbp
    mov rbp, rsp
    mov edx, esi                   ; unsigned mode
    mov esi, 577                   ; O_WRONLY | O_CREAT | O_TRUNC
    xor eax, eax                   ; no vector arguments to open
    call open
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
