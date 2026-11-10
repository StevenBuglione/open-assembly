; Original bounded SSE2 copy with an AVX path for enabled YMM state.
; Identical arguments and result to memcpy, including zero length.
bits 64
default rel

global __al_memcpy_bulk:function

section .text.__al_memcpy_bulk alloc exec nowrite progbits
__al_memcpy_bulk:
    mov r8, rdx
    mov r9, rdi
    mov eax, [rel vector_mode]
    test eax, eax
    jnz .select
    push rbx
    mov eax, 1                 ; basic feature information on x86-64
    xor ecx, ecx
    cpuid
    and ecx, 0x1c000000        ; XSAVE | OSXSAVE | AVX
    cmp ecx, 0x1c000000
    jne .baseline
    xor ecx, ecx              ; XCR0
    xgetbv
    and eax, 6                ; XMM and YMM state
    cmp eax, 6
    jne .baseline
    mov eax, 2
    jmp .publish
.baseline:
    mov eax, 1
.publish:
    pop rbx
    mov [rel vector_mode], eax
.select:
    cmp eax, 2
    jne .sse
    cmp r8, 128
    jb .avx_done
.avx_loop:
    vmovdqu ymm0, [rsi]
    vmovdqu ymm1, [rsi + 32]
    vmovdqu ymm2, [rsi + 64]
    vmovdqu ymm3, [rsi + 96]
    vmovdqu [rdi], ymm0
    vmovdqu [rdi + 32], ymm1
    vmovdqu [rdi + 64], ymm2
    vmovdqu [rdi + 96], ymm3
    add rsi, 128
    add rdi, 128
    sub r8, 128
    cmp r8, 128
    jae .avx_loop
.avx_done:
    vzeroupper

.sse:
    cmp r8, 32
    jb .tail
.sse_loop:
    movdqu xmm0, [rsi]
    movdqu xmm1, [rsi + 16]
    movdqu [rdi], xmm0
    movdqu [rdi + 16], xmm1
    add rsi, 32
    add rdi, 32
    sub r8, 32
    cmp r8, 32
    jae .sse_loop
.tail:
    test r8, r8
    jz .done
.byte:
    mov cl, [rsi]
    mov [rdi], cl
    inc rsi
    inc rdi
    dec r8
    jnz .byte
.done:
    mov rax, r9
    ret

section .bss.__al_memcpy_bulk alloc noexec write nobits align=4
vector_mode: resd 1

section .note.GNU-stack noalloc noexec nowrite progbits
