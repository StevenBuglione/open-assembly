; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fchmod
; header: sys/stat.h
; prototype: int fchmod(int fd, mode_t mode)
; standard: POSIX.1-2024 XSH fchmod
; deps: __errno_location
; errno: EBADF, EINTR, EIO, EINVAL, EPERM, EROFS
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: edi:s32, esi:u32
; variadic: false
; semantics: Set access and mode bits through the descriptor.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fchmod:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.fchmod alloc exec nowrite progbits
fchmod:
    sub rsp, 8
    mov qword [rsp], 0
    mov edx, esi
    movsxd rsi, edi
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 91                  ; __NR_fchmod
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
