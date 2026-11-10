; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ftruncate
; header: unistd.h
; prototype: int ftruncate(int fd, off_t length)
; standard: POSIX.1-2024 XSH ftruncate
; deps: __errno_location
; errno: EBADF, EFBIG, EINTR, EINVAL, EIO, EPERM, EROFS
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Resize a writable regular file to the requested signed length without changing its current offset.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ftruncate:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.ftruncate alloc exec nowrite progbits
ftruncate:
    sub rsp, 8
    mov qword [rsp], 0
    mov rdx, rsi
    movsxd rsi, edi
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 77                  ; __NR_ftruncate
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
