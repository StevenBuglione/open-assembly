; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: getpid
; header: unistd.h
; prototype: pid_t getpid(void)
; standard: POSIX.1-2024 XSH getpid
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-process-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the current Linux process ID without changing errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global getpid:function
extern __al_syscall:function

section .text.getpid alloc exec nowrite progbits
getpid:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov edi, 39                  ; __NR_getpid
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
