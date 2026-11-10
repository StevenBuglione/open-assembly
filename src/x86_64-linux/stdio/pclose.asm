; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pclose
; header: stdio.h
; prototype: int pclose(FILE *stream)
; standard: POSIX.1-2024 XSH pclose
; deps: close, free, __errno_location
; errno: ECHILD, EINVAL, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-shell-process
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Close a popen stream and wait for its associated child.
; semantics: Retry an interrupted wait. Return the raw wait status on success.
; semantics: Report stream or wait errors as -1 and errno. An unrelated stream fails with EINVAL and remains open.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pclose:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_stream_unlock_all:function
extern __al_stream_unpin:function
extern __al_stream_close:function
extern __al_syscall:function
extern __al_syscall_result:function
extern __errno_location:function

section .text.pclose alloc exec nowrite progbits
pclose:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 24
    mov rbx, rdi
    test rbx, rbx
    jz .invalid
    call __al_stream_lock
    mov r12, [rbx + 88]
    test r12, r12
    jle .unrelated
    mov qword [rbx + 88], 0
    mov rdi, rbx
    xor esi, esi
    call __al_stream_close
    xor r13d, r13d
    test eax, eax
    jz .unlock
    call __errno_location
    mov r13d, [rax]               ; keep the stream error through wait
.unlock:
    mov rdi, rbx
    call __al_stream_unlock_all
    mov rdi, rbx
    mov esi, 1
    call __al_stream_unpin
    mov qword [rsp], 0
.wait:
    mov rsi, r12
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 61                   ; __NR_wait4
    lea rdx, [rsp + 8]            ; four-byte child status
    call __al_syscall
    cmp rax, -4                   ; EINTR
    je .wait
    cmp rax, -4095
    jae .error
    test r13d, r13d
    jnz .stream_error
    mov eax, [rsp + 8]
    jmp .done
.stream_error:
    mov rax, r13
    neg rax
    jmp .error
.unrelated:
    mov rdi, rbx
    call __al_stream_unlock
.invalid:
    mov rax, -22                  ; EINVAL
.error:
    mov rdi, rax
    call __al_syscall_result
.done:
    add rsp, 24
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
