; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: lstat
; header: sys/stat.h
; prototype: int lstat(const char *restrict path, struct stat *restrict buf)
; standard: POSIX.1-2024 XSH lstat
; deps: fstatat
; errno: EACCES, EBADF, EFAULT, EINVAL, ELOOP, ENAMETOOLONG, ENOENT, ENOMEM, ENOTDIR, EOVERFLOW
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Obtain metadata for path without following a final symbolic link.
; semantics: Write the converted LP64 stat record only after the kernel reports success.
; semantics: Clear public padding and reserved words.
; semantics: Return zero on success and preserve errno. Return -1 and set errno on error.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global lstat:function
extern fstatat:function

section .text.lstat alloc exec nowrite progbits
lstat:
    push rbp
    mov rbp, rsp
    mov rdx, rsi
    mov rsi, rdi
    mov edi, -100                 ; AT_FDCWD
    mov ecx, 256                  ; AT_SYMLINK_NOFOLLOW
    call fstatat
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
