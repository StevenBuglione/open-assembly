; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fstat
; header: sys/stat.h
; prototype: int fstat(int fd, struct stat *buf)
; standard: POSIX.1-2024 XSH fstat
; deps: __errno_location
; errno: EACCES, EBADF, EFAULT, EINVAL, ELOOP, ENAMETOOLONG, ENOENT, ENOMEM, ENOTDIR, EOVERFLOW
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Obtain metadata for an open descriptor, including an unlinked file.
; semantics: Write the converted LP64 stat record only after the kernel reports success.
; semantics: Clear public padding and reserved words.
; semantics: Return zero on success and preserve errno. Return -1 and set errno on error.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fstat:function
extern __al_stat_query:function

section .text.fstat alloc exec nowrite progbits
fstat:
    push rbp
    mov rbp, rsp
    mov r8, rsi
    movsxd rsi, edi
    xor edx, edx
    xor ecx, ecx
    mov edi, 5                    ; __NR_fstat
    call __al_stat_query
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
