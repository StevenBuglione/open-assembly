; Original contended timed acquisition of a private mutex futex word.
; rdi = mutex, rsi = absolute deadline, edx = mode 2 realtime or 3 monotonic.
bits 64
default rel

global __al_mutex_timed_wait:function
extern __al_syscall:function

section .text.__al_mutex_timed_wait alloc exec nowrite progbits
__al_mutex_timed_wait:
    test rsi, rsi
    jz .invalid
    cmp qword [rsi + 8], 1000000000
    jae .invalid
    cmp qword [rsi], 0
    jl .expired
    push rbx
    push r12
    push r13
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13d, 137                 ; FUTEX_WAIT_BITSET_PRIVATE
    cmp edx, 2
    jne .retry
    or r13d, 256                  ; FUTEX_CLOCK_REALTIME
.retry:
    mov eax, 2
    xchg dword [rbx], eax
    test eax, eax
    jz .done
    mov qword [rsp], -1           ; FUTEX_BITSET_MATCH_ANY
    mov edi, 202                  ; __NR_futex
    mov rsi, rbx
    mov edx, r13d
    mov ecx, 2
    mov r8, r12
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jz .retry
    cmp rax, -11                  ; EAGAIN
    je .retry
    cmp rax, -4                   ; EINTR
    je .retry
    neg eax
.done:
    add rsp, 16
    pop r13
    pop r12
    pop rbx
    ret

.invalid:
    mov eax, 22                   ; EINVAL
    ret
.expired:
    mov eax, 110                  ; ETIMEDOUT
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
