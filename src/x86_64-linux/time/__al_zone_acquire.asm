; Original serialized zone cache. Return the selected zone while holding
; its lock. The caller releases __al_zone_lock after consuming the record.
bits 64
default rel

global __al_zone_acquire:function
global __al_zone_lock:data
extern __al_lock:function
extern __al_zone_load:function
extern getenv:function
extern strcmp:function
extern strlen:function
extern memcpy:function
extern malloc:function
extern free:function

section .text.__al_zone_acquire alloc exec nowrite progbits
__al_zone_acquire:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    lea rdi, [rel __al_zone_lock]
    call __al_lock
    lea rdi, [rel key_name]
    call getenv
    mov rbx, rax
    cmp byte [rel cache_known], 0
    je .replace
    mov rsi, [rel cache_key]
    test rbx, rbx
    jz .absent
    test rsi, rsi
    jz .replace
    mov rdi, rbx
    call strcmp
    test eax, eax
    jz .return
    jmp .replace
.absent:
    test rsi, rsi
    jz .return
.replace:
    xor r12d, r12d                ; new cache key
    xor r13d, r13d                ; new zone
    xor r14d, r14d                ; cache key is reproducible
    test rbx, rbx
    jz .load
    mov rdi, rbx
    call strlen
    add rax, 1
    jc .publish
    mov r13, rax
    mov rdi, rax
    call malloc
    test rax, rax
    jz .no_key
    mov r12, rax
    mov rdi, rax
    mov rsi, rbx
    mov rdx, r13
    call memcpy
.load:
    mov rdi, r12
    call __al_zone_load
    mov r13, rax
    mov r14d, 1
    jmp .publish
.no_key:
    xor r13d, r13d
.publish:
    mov rbx, [rel cache_zone]
    test rbx, rbx
    jz .free_key
    mov rdi, [rbx]
    call free
    mov rdi, rbx
    call free
.free_key:
    mov rdi, [rel cache_key]
    call free
    mov [rel cache_key], r12
    mov [rel cache_zone], r13
    mov [rel cache_known], r14b
.return:
    mov rax, [rel cache_zone]
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_zone_acquire alloc noexec nowrite progbits
key_name: db "TZ", 0

section .bss.__al_zone_acquire alloc noexec write nobits align=8
__al_zone_lock: resq 1
cache_key: resq 1
cache_zone: resq 1
cache_known: resb 1

section .note.GNU-stack noalloc noexec nowrite progbits
