; Resolve one of the thirteen persistent guards in fork acquisition order.
bits 64
default rel

global __al_fork_guard_at:function
extern __al_atfork_state:data
extern __al_setlocale_lock:data
extern __al_localeconv_lock:data
extern __al_zone_lock:data
extern __al_env_lock:data
extern __al_stdio_lock:data
extern __al_atexit_state:data
extern __al_quick_exit_state:data
extern __al_rand_state:data
extern __al_tsd_lock:data
extern __al_atomic_mutex:data
extern __al_tmpnam_lock:data
extern __al_heap_lock:data

section .text.__al_fork_guard_at alloc exec nowrite progbits
__al_fork_guard_at:
    lea rax, [rel __al_atfork_state]
    test edi, edi
    jz .return
    lea rax, [rel __al_setlocale_lock]
    cmp edi, 1
    je .return
    lea rax, [rel __al_localeconv_lock]
    cmp edi, 2
    je .return
    lea rax, [rel __al_zone_lock]
    cmp edi, 3
    je .return
    lea rax, [rel __al_env_lock]
    cmp edi, 4
    je .return
    lea rax, [rel __al_stdio_lock]
    cmp edi, 5
    je .return
    lea rax, [rel __al_atexit_state]
    cmp edi, 6
    je .return
    lea rax, [rel __al_quick_exit_state]
    cmp edi, 7
    je .return
    lea rax, [rel __al_rand_state + 8]
    cmp edi, 8
    je .return
    lea rax, [rel __al_tsd_lock]
    cmp edi, 9
    je .return
    lea rax, [rel __al_atomic_mutex]
    cmp edi, 10
    je .return
    lea rax, [rel __al_tmpnam_lock]
    cmp edi, 11
    je .return
    lea rax, [rel __al_heap_lock]
.return:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
