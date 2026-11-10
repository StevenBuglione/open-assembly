bits 64
default rel

section .rodata
message: db "Hello from assembly!", 10
message_size: equ $ - message

section .text.main progbits alloc exec nowrite align=16
global main:function
extern write
main:
    ; System V AMD64 ABI §3.2: at function entry, RSP + 8 is aligned
    ; to 16 bytes and DF is clear.
    mov eax, esp
    and eax, 15
    cmp eax, 8
    jne .bad_entry
    pushfq
    pop rax
    test eax, 1 << 10
    jnz .bad_entry

    sub rsp, 8
    mov edi, 1
    lea rsi, [message]
    mov edx, message_size
    call write
    add rsp, 8
    cmp rax, message_size
    jne .bad_write
    xor eax, eax
    ret
.bad_entry:
    mov eax, 41
    ret
.bad_write:
    mov eax, 42
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
