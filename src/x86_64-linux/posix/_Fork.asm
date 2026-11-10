; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: _Fork
; header: unistd.h
; prototype: pid_t _Fork(void)
; standard: POSIX.1-2024 XSH _Fork
; deps: __errno_location
; errno: EAGAIN, ENOMEM, ENOSYS
; mt_safe: true
; as_safe: true
; oracles: reference:linux-process-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Create a child through the raw Linux process operation without callbacks or runtime locks.
; semantics: Return zero in the child and its process ID in the parent.
; semantics: Preserve errno on success. Return minus one with errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global _Fork:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text._Fork alloc exec nowrite progbits
_Fork:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov edi, 57                  ; __NR_fork
    xor esi, esi
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
