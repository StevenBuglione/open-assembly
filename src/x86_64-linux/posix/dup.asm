; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: dup
; header: unistd.h
; prototype: int dup(int oldfd)
; standard: POSIX.1-2024 XSH dup
; deps: __errno_location
; errno: EBADF, EINTR, EMFILE, ENOMEM
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Duplicate the descriptor to the lowest free descriptor.
; semantics: Both descriptors refer to the same open file description.
; semantics: The new descriptor starts with close-on-exec clear.
; semantics: Preserve errno on success. Translate a Linux kernel error to -1 and thread-local errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global dup:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.dup alloc exec nowrite progbits
dup:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    movsxd rsi, edi                ; old descriptor
    mov edi, 32                    ; __NR_dup
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
