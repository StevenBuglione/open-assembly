; Original stream initialization. rdi = new FILE, rsi = fd, rdx = flags.
; The caller owns the registry lock. The final words describe ownership.
bits 64
default rel

global __al_stream_init:function
extern __al_stream_rebind:function

section .text.__al_stream_init alloc exec nowrite progbits
__al_stream_init:
    mov qword [rdi + 96], 0      ; lock word and registry pin count
    mov qword [rdi + 104], 0     ; recursive owner
    mov qword [rdi + 112], 0     ; owner depth
    mov rax, rdx
    and eax, 8
    shr eax, 3
    mov [rdi + 120], rax         ; immutable heap ownership and retirement
    sub rsp, 8
    call __al_stream_rebind
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
