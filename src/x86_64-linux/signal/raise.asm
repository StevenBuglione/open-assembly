; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: raise
; header: signal.h
; prototype: int raise(int sig)
; standard: C17 7.14.2.1
; deps: getpid, __errno_location
; errno: EINVAL, ESRCH
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-signal-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Deliver a supported nonzero signal to the calling thread using Linux thread-directed delivery.
; semantics: Return zero and preserve errno on success. Return -1 and set errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global raise:function
extern __al_syscall:function
extern __al_syscall_result:function
extern getpid:function

section .text.raise alloc exec nowrite progbits
raise:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 16
    movsxd rbx, edi               ; signal number
    cmp ebx, 1
    jl .invalid
    cmp ebx, 64
    ja .invalid
    call getpid
    movsxd r12, eax

    mov qword [rsp], 0
    mov edi, 186                  ; __NR_gettid
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .result

    mov qword [rsp], 0
    mov edi, 234                  ; __NR_tgkill
    mov rsi, r12                  ; current process
    mov rdx, rax                  ; current thread
    mov rcx, rbx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    jmp .result
.invalid:
    mov rax, -22                  ; EINVAL
.result:
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
