; Original realtime dispatch into a private Linux time64 result.
; Match __al_clock_parts: status in rax, seconds in rdx, nanoseconds in rcx.
bits 64
default rel

global __al_realtime_parts:function
extern __al_vdso_clock_entry:function
extern __al_clock_parts:function

section .text.__al_realtime_parts alloc exec nowrite progbits
__al_realtime_parts:
    sub rsp, 24
    call __al_vdso_clock_entry
    test rax, rax
    jz .fallback
    xor edi, edi               ; CLOCK_REALTIME
    lea rsi, [rsp]
    call rax
    test eax, eax
    jnz .fallback
    mov rdx, [rsp]
    mov rcx, [rsp + 8]
    xor eax, eax
    jmp .done
.fallback:
    xor edi, edi
    call __al_clock_parts
.done:
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
