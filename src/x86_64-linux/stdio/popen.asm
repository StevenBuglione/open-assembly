; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: popen
; header: stdio.h
; prototype: FILE *popen(const char *command, const char *mode)
; standard: POSIX.1-2024 XSH popen
; deps: malloc, free, pipe2, fork, close, _exit, __errno_location
; errno: EAGAIN, EINVAL, EMFILE, ENFILE, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-shell-process
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Run the command with /bin/sh -c and return a one-way byte stream for mode r or w.
; semantics: An optional e suffix keeps the returned descriptor close-on-exec.
; semantics: The shell child closes previously established popen descriptors before executing.
; semantics: Associate exactly one child with the returned stream. Report setup errors as null and errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global popen:function
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function
extern __al_stream_init:function
extern __al_fcntl:function
extern __al_popen_child:function
extern __al_spawn_reap:function
extern __al_syscall_result:function
extern __errno_location:function
extern malloc:function
extern free:function
extern pipe2:function
extern fork:function
extern close:function
extern kill:function

section .text.popen alloc exec nowrite progbits
popen:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24
    mov rbx, rdi
    test rbx, rbx
    jz .invalid
    test rsi, rsi
    jz .invalid
    movzx eax, byte [rsi]
    mov r15d, 1                   ; parent reads child output
    cmp eax, 114                  ; r
    je .suffix
    mov r15d, 2                   ; parent writes child input
    cmp eax, 119                  ; w
    jne .invalid
.suffix:
    cmp byte [rsi + 1], 0
    je .allocate
    cmp byte [rsi + 1], 101       ; e
    jne .invalid
    cmp byte [rsi + 2], 0
    jne .invalid
    or r15d, 4
.allocate:
    call __errno_location
    mov eax, [rax]
    mov [rsp + 8], eax            ; preserve errno after successful creation
    mov edi, 4224                 ; FILE and its inline buffer
    call malloc
    test rax, rax
    jz .done
    mov r12, rax
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    lea rdi, [r12 + 112]          ; unused FILE storage before registration
    mov esi, 0x80000              ; O_CLOEXEC
    call pipe2
    test eax, eax
    js .release
    movsxd r13, dword [r12 + 112]
    movsxd r14, dword [r12 + 116]
    test r15d, 1
    jnz .create_child
    mov rax, r13                  ; writing stream uses the opposite ends
    mov r13, r14
    mov r14, rax
.create_child:
    call fork
    test eax, eax
    js .fork_failed
    jz .child
    movsxd rax, eax
    mov [rsp], rax                ; parent child ID
    mov rdi, r14
    call close
    test r15d, 4
    jnz .register
    mov rdi, r13
    mov esi, 2                    ; F_SETFD
    xor edx, edx                  ; ordinary mode leaves descriptor inheritable
    call __al_fcntl
    cmp rax, -4095
    jae .after_fork_error
.register:
    mov rdi, r12
    mov rsi, r13
    mov edx, r15d
    and edx, 3
    or edx, 8                     ; heap-owned stream
    call __al_stream_init
    mov rax, [rsp]
    mov [r12 + 88], rax
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    call __errno_location
    mov edx, [rsp + 8]
    mov [rax], edx
    mov rax, r12
    jmp .done
.fork_failed:
    call __errno_location
    movsxd rax, dword [rax]
    neg rax
    mov [rsp + 16], rax
    mov rdi, r14
    call close
    mov rdi, r13
    call close
    jmp .restore_error
.after_fork_error:
    mov [rsp + 16], rax
    mov rdi, r13
    call close
    mov rdi, [rsp]
    mov esi, 9                    ; SIGKILL
    call kill
    mov rdi, [rsp]
    call __al_spawn_reap
.restore_error:
    mov rdi, [rsp + 16]
    call __al_syscall_result
.release:
    mov rdi, r12
    call free
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    xor eax, eax
    jmp .done
.invalid:
    mov rdi, -22                  ; EINVAL
    call __al_syscall_result
    xor eax, eax
.done:
    add rsp, 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.child:
    mov rdi, rbx
    mov rsi, r13
    mov rdx, r14
    xor ecx, ecx                  ; stdin for a parent writing stream
    test r15d, 1
    jz .redirect
    inc ecx                       ; stdout for a parent reading stream
.redirect:
    call __al_popen_child
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
