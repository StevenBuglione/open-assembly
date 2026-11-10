; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fchown
; header: unistd.h
; prototype: int fchown(int fd, uid_t owner, gid_t group)
; standard: POSIX.1-2024 XSH fchown
; deps: __errno_location
; errno: EBADF, EINTR, EIO, EINVAL, EPERM, EROFS
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: edi:s32, esi:u32, edx:u32
; variadic: false
; semantics: Set file ownership through its descriptor. All-one bits in either ID preserve that field.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fchown:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.fchown alloc exec nowrite progbits
fchown:
    sub rsp, 8
    mov qword [rsp], 0
    mov ecx, edx
    mov edx, esi
    movsxd rsi, edi
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 93                  ; __NR_fchown
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
