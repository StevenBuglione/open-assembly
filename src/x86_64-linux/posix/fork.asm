; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fork
; header: unistd.h
; prototype: pid_t fork(void)
; standard: POSIX.1-2024 XSH fork
; deps: __errno_location
; errno: EAGAIN, ENOMEM, ENOSYS
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-process-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Create a child process in the initial single-threaded runtime.
; semantics: Return zero in the child and its process ID in the parent.
; semantics: Preserve errno on success in both processes. Return -1 and set errno on failure.
; semantics: Threaded fork callbacks and child lock recovery belong to the later threading phase.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fork:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.fork alloc exec nowrite progbits
fork:
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
