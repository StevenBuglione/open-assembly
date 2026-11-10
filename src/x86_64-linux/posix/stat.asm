; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: stat
; header: sys/stat.h
; prototype: int stat(const char *restrict path, struct stat *restrict buf)
; standard: POSIX.1-2024 XSH stat
; deps: fstatat
; errno: EACCES, EBADF, EFAULT, EINVAL, ELOOP, ENAMETOOLONG, ENOENT, ENOMEM, ENOTDIR, EOVERFLOW
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Obtain metadata for path, following a final symbolic link.
; semantics: Write the converted LP64 stat record only after the kernel reports success.
; semantics: Clear public padding and reserved words.
; semantics: Return zero on success and preserve errno. Return -1 and set errno on error.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global stat:function
extern fstatat:function

section .text.stat alloc exec nowrite progbits
stat:
    push rbp
    mov rbp, rsp
    mov rdx, rsi
    mov rsi, rdi
    mov edi, -100                 ; AT_FDCWD
    xor ecx, ecx
    call fstatat
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
