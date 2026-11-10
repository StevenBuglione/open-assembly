; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: thrd_sleep
; header: threads.h
; prototype: int thrd_sleep(const struct timespec *duration, struct timespec *remaining)
; standard: C17 7.26.5.7
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Sleep for the relative duration. Return -1 with any requested remainder on interruption, or -2 on another error.
; semantics: Publish the remainder only on interruption and allow duration and remaining to alias.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global thrd_sleep:function
extern __al_syscall:function

section .text.thrd_sleep alloc exec nowrite progbits
thrd_sleep:
    push rbx
    sub rsp, 32
    mov qword [rsp], 0
    mov rbx, rsi
    mov rsi, rdi
    mov edi, 35                  ; __NR_nanosleep
    lea rdx, [rsp + 8]           ; isolate caller state from non-EINTR results
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jz .done
    cmp rax, -4                  ; EINTR
    je .interrupted
    mov eax, -2
    jmp .done

.interrupted:
    mov eax, -1
    test rbx, rbx
    jz .done
    mov rcx, [rsp + 8]
    mov [rbx], rcx
    mov rcx, [rsp + 16]
    mov [rbx + 8], rcx
.done:
    add rsp, 32
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
