; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: utimes
; header: sys/time.h
; prototype: int utimes(const char *path, const struct timeval times[2])
; standard: POSIX.1-2024 XSH utimes
; deps: __errno_location
; errno: EACCES, EFAULT, EINVAL, EIO, ELOOP, ENAMETOOLONG, ENOENT, ENOTDIR, EPERM, EROFS
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Set file access and modification time from two timeval records. A null pointer selects the current time.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global utimes:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.utimes alloc exec nowrite progbits
utimes:
    sub rsp, 8
    mov qword [rsp], 0
    mov rdx, rsi
    mov rsi, rdi
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 235                 ; __NR_utimes
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
