; Original condition wait. Inputs: condition, mutex, optional absolute
; deadline, and clock override (-1 to use the condition clock).
bits 64
default rel

global __al_cond_wait:function
extern __al_clock_parts:function
extern __al_lock:function
extern __al_unlock:function
extern __al_futex:function
extern __al_syscall:function
extern __al_panic:function
extern __errno_location:function
extern pthread_mutex_lock:function
extern pthread_mutex_unlock:function

section .text.__al_cond_wait alloc exec nowrite progbits
__al_cond_wait:
    test rdi, rdi
    jz .invalid_entry
    test rsi, rsi
    jz .invalid_entry
    cmp dword [rdi + 12], 0
    jne .invalid_entry
    cmp qword [rsi + 24], 0
    jne .invalid_entry
    cmp rcx, -1
    jne .clock
    movsxd rcx, dword [rdi + 4]
.clock:
    cmp rcx, 1
    ja .invalid_entry
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov [rsp + 8], rcx            ; realtime or monotonic
    mov qword [rsp + 16], 0      ; whether the user mutex was released
    call __errno_location
    lea r14, [rax + 0xc0]        ; private TLS waiter at TP + 0x100
    mov rax, [rax + 8]
    cmp rax, [r12 + 8]
    jne .not_owner
    cmp dword [r12 + 16], 1
    jne .invalid
    test r13, r13
    jz .register
    cmp qword [r13 + 8], 1000000000
    jae .invalid
    mov rdi, [rsp + 8]
    call __al_clock_parts
    test rax, rax
    js .clock_error
    cmp rdx, [r13]
    jl .register
    jg .expired
    cmp rcx, [r13 + 8]
    jae .expired

.register:
    mov qword [r14], 0
    mov dword [r14 + 8], 0
    mov rdi, rbx
    call __al_lock
    cmp dword [rbx + 12], 0
    jne .destroyed
    cmp dword [rbx + 8], -1
    je .waiter_limit
    add dword [rbx + 8], 1
    mov rax, [rbx + 24]
    test rax, rax
    jz .first_waiter
    mov [rax], r14
    jmp .append
.first_waiter:
    mov [rbx + 16], r14
.append:
    mov [rbx + 24], r14
    mov rdi, rbx
    call __al_unlock

    mov rdi, r12
    call pthread_mutex_unlock
    mov r15d, eax
    test eax, eax
    jnz .collect
    mov qword [rsp + 16], 1
.wait:
    cmp dword [r14 + 8], 0
    jne .notified
    test r13, r13
    jnz .timed
    lea rdi, [r14 + 8]
    mov esi, 128                 ; FUTEX_WAIT_PRIVATE
    xor edx, edx
    call __al_futex
    jmp .wait_result
.timed:
    mov eax, -1
    mov [rsp], rax               ; FUTEX_BITSET_MATCH_ANY
    mov edi, 202                 ; __NR_futex
    lea rsi, [r14 + 8]
    mov edx, 137                 ; FUTEX_WAIT_BITSET_PRIVATE
    cmp qword [rsp + 8], 0
    jne .deadline
    or edx, 256                  ; FUTEX_CLOCK_REALTIME
.deadline:
    xor ecx, ecx                 ; expected wake flag
    mov r8, r13                  ; absolute time64 deadline
    xor r9d, r9d
    call __al_syscall
.wait_result:
    test rax, rax
    jns .wait
    cmp rax, -4
    je .wait
    cmp rax, -11
    je .wait
    neg eax
    mov r15d, eax
    jmp .collect
.notified:
    xor r15d, r15d

.collect:
    mov rdi, rbx
    call __al_lock               ; wait for any in-flight wake to finish
    cmp dword [r14 + 8], 0
    jne .selected
    lea rdx, [rbx + 16]
    xor ecx, ecx
.find:
    mov rax, [rdx]
    cmp rax, r14
    je .unlink
    test rax, rax
    jz .corrupt
    mov rcx, rax
    mov rdx, rax
    jmp .find
.unlink:
    mov rax, [r14]
    mov [rdx], rax
    cmp [rbx + 24], r14
    jne .remove_count
    mov [rbx + 24], rcx
    jmp .remove_count
.selected:
    cmp r15d, 110                ; a signal may win a concurrent timeout
    jne .remove_count
    xor r15d, r15d
.remove_count:
    sub dword [rbx + 8], 1
    mov rdi, rbx
    call __al_unlock
    cmp qword [rsp + 16], 0
    jz .return_result
.relock:
    mov rdi, r12
    call pthread_mutex_lock
    test eax, eax
    jnz .done
.return_result:
    mov eax, r15d
    jmp .done

.expired:
    mov rdi, r12
    call pthread_mutex_unlock
    test eax, eax
    jnz .done
    mov r15d, 110                ; already expired, still release and reacquire
    jmp .relock
.waiter_limit:
    mov r15d, 11
    jmp .unlock_error
.destroyed:
    mov r15d, 22
.unlock_error:
    mov rdi, rbx
    call __al_unlock
    jmp .return_result
.not_owner:
    mov eax, 1
    jmp .done
.invalid:
    mov eax, 22
    jmp .done
.clock_error:
    neg eax
.done:
    add rsp, 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.invalid_entry:
    mov eax, 22
    ret
.corrupt:
    lea rdi, [rel queue_error]
    mov esi, 39
    call __al_panic
    ud2

section .rodata.__al_cond_wait alloc noexec nowrite progbits
queue_error: db "open-assembly: damaged condition queue", 10

section .note.GNU-stack noalloc noexec nowrite progbits
