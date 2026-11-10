; Original runtime lock. The pointer identifies an aligned zeroed 32-bit word.
bits 64
default rel

global __al_lock:function
extern __al_futex:function
extern __al_panic:function

section .text.__al_lock alloc exec nowrite progbits
__al_lock:
    xor eax, eax
    mov edx, 1
    lock cmpxchg dword [rdi], edx
    jz .acquired

    push rbx
    mov rbx, rdi
.contended:
    mov eax, 2
    xchg dword [rbx], eax
    test eax, eax
    jz .acquired_contended
    cmp eax, 2
    ja .failure
    mov rdi, rbx
    mov esi, 128                  ; FUTEX_WAIT_PRIVATE
    mov edx, 2
    call __al_futex
    test rax, rax
    jz .contended
    cmp rax, -11                 ; EAGAIN: value changed before the wait
    je .contended
    cmp rax, -4                  ; EINTR: retry the acquisition
    je .contended
.failure:
    lea rdi, [rel lock_error]
    mov esi, 41
    call __al_panic
    ud2
.acquired_contended:
    pop rbx
.acquired:
    ret

section .rodata.__al_lock alloc noexec nowrite progbits
lock_error: db "open-assembly: cannot lock runtime futex", 10

section .note.GNU-stack noalloc noexec nowrite progbits
