; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fstatat
; header: sys/stat.h
; prototype: int fstatat(int dirfd, const char *restrict path, struct stat *restrict buf, int flags)
; standard: POSIX.1-2024 XSH fstatat
; deps: __errno_location
; errno: EACCES, EBADF, EFAULT, EINVAL, ELOOP, ENAMETOOLONG, ENOENT, ENOMEM, ENOTDIR, EOVERFLOW
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: edi:s32, ecx:s32
; variadic: false
; semantics: Resolve relative paths from dirfd or AT_FDCWD. An absolute path ignores dirfd.
; semantics: AT_SYMLINK_NOFOLLOW selects the final symbolic link itself.
; semantics: Linux AT_EMPTY_PATH with an empty string selects dirfd itself.
; semantics: Write the converted LP64 stat record only after the kernel reports success.
; semantics: Clear public padding and reserved words.
; semantics: Return zero on success and preserve errno. Return -1 and set errno on error.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fstatat:function
extern __al_stat_query:function

section .text.fstatat alloc exec nowrite progbits
fstatat:
    push rbp
    mov rbp, rsp
    mov r8, rdx
    mov rdx, rsi
    movsxd rsi, edi
    movsxd rcx, ecx
    mov edi, 262                  ; __NR_newfstatat
    call __al_stat_query
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
