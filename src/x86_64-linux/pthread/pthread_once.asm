; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_once
; header: pthread.h
; prototype: int pthread_once(pthread_once_t *control, void (*initialize)(void))
; standard: POSIX.1-2024 XSH pthread_once
; deps: pthread_self
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:thread-once
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Run one initialization routine for each properly initialized control.
; semantics: Publish the effects of the completed callback before successful return of any caller.
; semantics: Retry wait interruptions inside the operation. Preserve errno on paths that do not invoke the callback.
; semantics: Allow a new caller to initialize the control if the current initializer leaves through pthread_exit.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_once:function
extern pthread_self:function
extern __al_futex:function
extern __al_once_wake:function

section .text.pthread_once alloc exec nowrite progbits
pthread_once:
    push rbx
    push r12
    push r13
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
.retry:
    xor eax, eax
    mov edx, 1
    lock cmpxchg dword [rbx], edx
    jz .initialize
    cmp eax, 2
    je .success
    cmp eax, 1
    jne .invalid
    mov rdi, rbx
    mov esi, 128                  ; FUTEX_WAIT_PRIVATE
    mov edx, 1
    call __al_futex
    test rax, rax
    jz .retry
    cmp rax, -11                  ; EAGAIN
    je .retry
    cmp rax, -4                   ; EINTR
    je .retry
.invalid:
    mov eax, 22                   ; EINVAL
    jmp .done

.initialize:
    call pthread_self
    mov r13, rax
    mov rax, [r13 + 0x910]
    mov [rsp], rax
    mov [rsp + 8], rbx
    lea rax, [rsp]
    mov [r13 + 0x910], rax
    mov rax, r12
    call rax
    mov rax, [rsp]
    mov [r13 + 0x910], rax
    mov dword [rbx], 2            ; release on AMD64
    mov rdi, rbx
    call __al_once_wake
.success:
    xor eax, eax
.done:
    add rsp, 16
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
