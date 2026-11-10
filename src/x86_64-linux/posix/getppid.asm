; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: getppid
; header: unistd.h
; prototype: pid_t getppid(void)
; standard: POSIX.1-2024 XSH getppid
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-process-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the current Linux parent process ID without changing errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global getppid:function
extern __al_syscall:function

section .text.getppid alloc exec nowrite progbits
getppid:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov edi, 110                 ; __NR_getppid
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
