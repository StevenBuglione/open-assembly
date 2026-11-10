; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: close
; header: unistd.h
; prototype: int close(int fd)
; standard: POSIX.1-2024 XSH close
; deps: __errno_location
; errno: EBADF, EINTR, EIO, ENOSPC, EDQUOT
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:linux-close
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Perform one Linux close operation and return zero on success without changing errno.
; semantics: Return -1 and set errno to the positive kernel error on failure.
; semantics: On Linux an EINTR result does not leave the descriptor open; do not retry close.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global close:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.close alloc exec nowrite progbits
close:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    movsxd rsi, edi
    mov edi, 3                     ; __NR_close
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
