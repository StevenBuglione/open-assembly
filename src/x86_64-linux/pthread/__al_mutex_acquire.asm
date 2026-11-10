; Original process-private mutex acquisition. Inputs: mutex, mode and optional deadline.
bits 64
default rel

global __al_mutex_acquire:function
extern __errno_location:function
extern __al_lock:function
extern __al_mutex_timed_wait:function

section .text.__al_mutex_acquire alloc exec nowrite progbits
__al_mutex_acquire:
    test rdi, rdi
    jz .invalid
    cmp qword [rdi + 24], 0
    jne .invalid
    cmp dword [rdi + 4], 2
    ja .invalid
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8
    mov rbx, rdi
    mov r13, rsi
    mov r14, rdx
    call __errno_location
    mov r12, [rax + 8]           ; process-unique thread ownership token
    cmp [rbx + 8], r12
    jne .acquire
    cmp dword [rbx + 4], 2
    je .recursive
    cmp r13d, 1
    je .busy
    cmp dword [rbx + 4], 1
    je .deadlock
.acquire:
    test r13d, r13d
    jnz .try
    mov rdi, rbx
    call __al_lock
    jmp .publish
.try:
    xor eax, eax
    mov edx, 1
    lock cmpxchg dword [rbx], edx
    jz .publish
    cmp r13d, 1
    je .busy
    mov rdi, rbx
    mov rsi, r14
    mov edx, r13d
    call __al_mutex_timed_wait
    test eax, eax
    jnz .done
.publish:
    mov dword [rbx + 16], 1
    mov [rbx + 8], r12
    jmp .success
.recursive:
    cmp dword [rbx + 16], -1
    je .count_limit
    add dword [rbx + 16], 1
.success:
    xor eax, eax
    jmp .done
.busy:
    mov eax, 16                  ; EBUSY
    jmp .done
.deadlock:
    mov eax, 35                  ; EDEADLK
    jmp .done
.count_limit:
    mov eax, 11                  ; EAGAIN
.done:
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.invalid:
    mov eax, 22                  ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
