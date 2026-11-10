; Round x*y+z once. edi format; rsi,rdx,rcx raw low words; r8 three packed high words.
bits 64
default rel

global __al_math_fma:function
extern __al_fp_decode:function
extern __al_fp_pack_exact:function
extern __al_fp_special:function
extern __al_fp_quiet:function
extern __al_math_effects:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_add:function
extern __al_big_cmp:function
extern __al_big_sub:function
extern __al_float_round:function
extern fegetround:function

section .text.__al_math_fma alloc exec nowrite progbits
__al_math_fma:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 80
    mov ebx, edi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8

    movzx edx, r15w
    call __al_fp_decode
    mov [rsp], rax
    mov [rsp + 24], edx
    mov [rsp + 36], r8d
    mov [rsp + 48], ecx
    mov edi, ebx
    mov rsi, r13
    mov rdx, r15
    shr rdx, 16
    movzx edx, dx
    call __al_fp_decode
    mov [rsp + 8], rax
    mov [rsp + 28], edx
    mov [rsp + 40], r8d
    xor [rsp + 48], ecx          ; product sign
    mov edi, ebx
    mov rsi, r14
    mov rdx, r15
    shr rdx, 32
    call __al_fp_decode
    mov [rsp + 16], rax
    mov [rsp + 32], edx
    mov [rsp + 44], r8d
    mov [rsp + 52], ecx

    cmp dword [rsp + 36], 5
    je .signaling_x
    cmp dword [rsp + 40], 5
    je .signaling_y
    cmp r8d, 5
    je .signaling_z
    cmp dword [rsp + 36], 4
    je .return_x
    cmp dword [rsp + 40], 4
    je .return_y
    cmp r8d, 4
    je .return_z

    cmp dword [rsp + 36], 3
    je .x_infinite
    cmp dword [rsp + 40], 3
    je .y_infinite
    cmp r8d, 3
    je .return_z
    cmp dword [rsp + 36], 0
    je .product_zero
    cmp dword [rsp + 40], 0
    je .product_zero
    jmp .finite
.x_infinite:
    cmp dword [rsp + 40], 0
    je .domain
    jmp .infinite_product
.y_infinite:
    cmp dword [rsp + 36], 0
    je .domain
.infinite_product:
    mov edx, [rsp + 48]
    cmp dword [rsp + 44], 3
    jne .infinite_result
    cmp edx, [rsp + 52]
    jne .domain
.infinite_result:
    mov edi, ebx
    xor esi, esi
    call __al_fp_special
    jmp .done
.product_zero:
    cmp r8d, 0
    jne .return_z
    mov ecx, [rsp + 48]
    cmp ecx, [rsp + 52]
    je .pack_zero
    jmp .signed_cancellation

.finite:
    mov eax, [rsp + 24]
    add eax, [rsp + 28]
    mov [rsp + 56], eax          ; product exponent
    cmp qword [rsp + 16], 0
    je .common_exponent
    cmp eax, [rsp + 32]
    jle .common_exponent
    mov eax, [rsp + 32]
.common_exponent:
    mov [rsp + 60], eax          ; minimum addend exponent
    lea rdi, [rel scratch_lock]
    call __al_lock
    mov rax, [rsp]
    mov r10, [rsp + 8]
    mul r10
    lea r12, [rel product]
    lea r13, [rel addend]
    mov rdi, r12
    mov rsi, rax
    call __al_big_init128
    mov rdi, r12
    mov esi, [rsp + 56]
    sub esi, [rsp + 60]
    call __al_big_left

    mov ecx, [rsp + 48]
    mov [rel metadata + 8], rcx
    mov rsi, [rsp + 16]
    test rsi, rsi
    jz .round
    mov rdi, r13
    xor edx, edx
    call __al_big_init128
    mov rdi, r13
    mov esi, [rsp + 32]
    sub esi, [rsp + 60]
    call __al_big_left
    mov ecx, [rsp + 52]
    cmp ecx, [rsp + 48]
    jne .subtract
    mov rdi, r12
    mov rsi, r13
    call __al_big_add
    jmp .round
.subtract:
    mov rdi, r12
    mov rsi, r13
    call __al_big_cmp
    test eax, eax
    jz .unlock_cancellation
    jg .difference
    mov rax, r12
    mov r12, r13
    mov r13, rax
    mov ecx, [rsp + 52]
    mov [rel metadata + 8], rcx
.difference:
    mov rdi, r12
    mov rsi, r13
    call __al_big_sub

.round:
    movsxd rax, dword [rsp + 60]
    mov [rel metadata + 16], rax
    mov qword [rel metadata + 24], 2
    mov qword [rel metadata + 32], 0
    mov rdi, r12
    mov rsi, r13
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_float_round
    mov [rsp + 64], ecx
    mov r8, [rel metadata + 8]
    cmp ebx, 2
    je .extended_bits
    test ebx, ebx
    jz .single_bits
    shl rax, 12
    shr rax, 12
    shl rdx, 52
    shl r8, 63
    or rax, rdx
    or rax, r8
    jmp .unlock_result
.single_bits:
    and eax, 0x7fffff
    shl edx, 23
    shl r8d, 31
    or eax, edx
    or eax, r8d
    jmp .unlock_result
.extended_bits:
    shl r8d, 15
    or edx, r8d
.unlock_result:
    mov r12, rax
    mov r13d, edx
    lea rdi, [rel scratch_lock]
    call __al_unlock
    mov edi, [rsp + 64]
    xor esi, esi
    test edi, 24
    jz .effects
    mov esi, 34
.effects:
    call __al_math_effects
    jmp .original
.unlock_cancellation:
    lea rdi, [rel scratch_lock]
    call __al_unlock
.signed_cancellation:
    call fegetround
    xor ecx, ecx
    cmp eax, 1024
    jne .pack_zero
    mov ecx, 1
.pack_zero:
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    call __al_fp_pack_exact
    jmp .done

.domain:
    mov edi, 1
    mov esi, 33
    call __al_math_effects
    mov edi, ebx
    mov esi, 2
    xor edx, edx
    call __al_fp_special
    jmp .done
.signaling_x:
    movzx r13d, r15w
    jmp .quiet
.signaling_y:
    mov r12, r13
    mov r13, r15
    shr r13, 16
    movzx r13d, r13w
    jmp .quiet
.signaling_z:
    mov r12, r14
    mov r13, r15
    shr r13, 32
.quiet:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    call __al_fp_quiet
    mov r12, rax
    mov r13d, edx
    mov edi, 1
    xor esi, esi
    call __al_math_effects
    jmp .original
.return_x:
    movzx r13d, r15w
    jmp .original
.return_y:
    mov r12, r13
    mov r13, r15
    shr r13, 16
    movzx r13d, r13w
    jmp .original
.return_z:
    mov r12, r14
    mov r13, r15
    shr r13, 32
.original:
    mov rax, r12
    mov edx, r13d
.done:
    add rsp, 80
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss.__al_math_fma alloc noexec write nobits align=8
scratch_lock:
    resq 1
metadata:
    resq 6
product:
    resq 1281
addend:
    resq 1281
comparison:
    resq 1281

section .note.GNU-stack noalloc noexec nowrite progbits
