; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fsync
; header: unistd.h
; prototype: int fsync(int fd)
; standard: POSIX.1-2024 XSH fsync
; deps: __errno_location
; errno: EBADF, EINTR, EINVAL, EIO, ENOSPC, EROFS
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Synchronize file contents and metadata through the descriptor.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fsync:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.fsync alloc exec nowrite progbits
fsync:
    sub rsp, 8
    mov qword [rsp], 0
    movsxd rsi, edi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 74                  ; __NR_fsync
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
