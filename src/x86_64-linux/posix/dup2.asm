; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: dup2
; header: unistd.h
; prototype: int dup2(int oldfd, int newfd)
; standard: POSIX.1-2024 XSH dup2
; deps: __errno_location
; errno: EBADF, EBUSY, EINTR, EMFILE, ENOMEM
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: edi:s32, esi:s32
; variadic: false
; semantics: Atomically replace newfd with a duplicate of oldfd.
; semantics: If oldfd is valid and equals newfd, return it with its descriptor flags preserved.
; semantics: An invalid oldfd leaves an existing newfd in place.
; semantics: Preserve errno on success. Translate a Linux kernel error to -1 and thread-local errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global dup2:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.dup2 alloc exec nowrite progbits
dup2:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    movsxd rdx, esi                ; new descriptor
    movsxd rsi, edi                ; old descriptor
    mov edi, 33                    ; __NR_dup2
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
