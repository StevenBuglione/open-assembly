; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: signal
; header: signal.h
; prototype: __al_sighandler_t signal(int sig, __al_sighandler_t handler)
; standard: C17 7.14.1.1
; deps: __errno_location
; errno: EINVAL
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-signal-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Install a one-argument handler, SIG_DFL, or SIG_IGN with persistent BSD signal semantics.
; semantics: Block the current signal while a handler runs and request SA_RESTART.
; semantics: Return the prior handler and preserve errno on success. Return SIG_ERR and set errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global signal:function
extern __al_syscall:function
extern __al_syscall_result:function
extern __al_rt_sigreturn:function

section .text.signal alloc exec nowrite progbits
signal:
    push rbp
    mov rbp, rsp
    sub rsp, 80
    movsxd rax, edi
    cmp rsi, -1                   ; SIG_ERR is not an installable disposition
    je .invalid
    mov qword [rsp], 0
    mov [rsp + 8], rsi
    mov qword [rsp + 16], 0x14000000 ; SA_RESTART | SA_RESTORER
    lea rdx, [rel __al_rt_sigreturn]
    mov [rsp + 24], rdx
    mov qword [rsp + 32], 0        ; no additional blocked signals
    mov rsi, rax
    mov r8d, 8
    xor r9d, r9d
    mov edi, 13                   ; __NR_rt_sigaction
    lea rcx, [rsp + 40]
    lea rdx, [rsp + 8]
    call __al_syscall
    cmp rax, -4095
    jae .error
    mov rax, [rsp + 40]           ; previous handler
    jmp .done
.invalid:
    mov rax, -22                  ; EINVAL
.error:
    mov rdi, rax
    call __al_syscall_result
.done:
    add rsp, 80
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
