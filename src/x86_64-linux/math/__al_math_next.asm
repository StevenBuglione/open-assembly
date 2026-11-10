; Step encoded x (edi/rsi/edx) toward encoded y (ecx/r8/r9d). Result has x's kind.
bits 64
default rel

global __al_math_next:function
extern __al_fp_decode:function
extern __al_fp_pack_exact:function
extern __al_fp_quiet:function
extern __al_fp_special:function
extern __al_math_effects:function

section .text.__al_math_next alloc exec nowrite progbits
__al_math_next:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov ebx, edi
    mov r12, rsi
    mov r13d, edx
    mov r14, r8
    mov r15d, r9d
    mov [rsp + 20], ecx           ; y kind
    call __al_fp_decode
    mov [rsp], r8d                ; x class
    mov [rsp + 4], ecx            ; x sign
    cmp r8d, 3
    je .x_infinite
    test r8d, r8d
    jz .x_zero
    cmp r8d, 3
    ja .decode_y
    bsr r10, rax
    add edx, r10d
    mov ecx, 63
    sub ecx, r10d
    shl rax, cl
    jmp .x_magnitude
.x_infinite:
    mov edx, 0x7fffffff
    jmp .x_sentinel
.x_zero:
    mov edx, 0x80000000
.x_sentinel:
    xor eax, eax
.x_magnitude:
    mov [rsp + 8], rax            ; normalized x significand
    mov [rsp + 16], edx           ; x leading exponent

.decode_y:
    mov edi, [rsp + 20]
    mov rsi, r14
    mov edx, r15d
    call __al_fp_decode
    mov [rsp + 24], ecx           ; y sign
    mov dword [rsp + 28], 0       ; signaling NaN status
    cmp dword [rsp], 5
    je .mark_signaling
    cmp r8d, 5
    jne .select_nan
.mark_signaling:
    mov dword [rsp + 28], 1
.select_nan:
    cmp dword [rsp], 4
    jae .quiet_x
    cmp r8d, 4
    jae .quiet_y

    cmp dword [rsp], 0
    je .zero_x
    cmp ecx, [rsp + 4]
    jne .shrink
    cmp r8d, 3
    je .y_infinite
    test r8d, r8d
    jz .shrink
    bsr r10, rax
    add edx, r10d
    cmp edx, [rsp + 16]
    jg .grow
    jl .shrink
    mov ecx, 63
    sub ecx, r10d
    shl rax, cl
    cmp rax, [rsp + 8]
    ja .grow
    jb .shrink
    jmp .original
.y_infinite:
    cmp dword [rsp], 3
    je .original
    jmp .grow

.zero_x:
    mov edi, ebx
    xor esi, esi
    test r8d, r8d
    jz .pack_zero
    mov esi, 1
.pack_zero:
    mov edx, -149
    test ebx, ebx
    jz .zero_exponent
    mov edx, -1074
    cmp ebx, 1
    je .zero_exponent
    mov edx, -16445
.zero_exponent:
    mov r14d, esi
    call __al_fp_pack_exact
    mov r12, rax
    mov r13d, edx
    test r14d, r14d
    jnz .underflow
    jmp .original

.grow:
    cmp ebx, 2
    je .extended_grow
    inc r12
    jmp .check_range
.extended_grow:
    inc r12
    jz .extended_carry
    mov r10, 0x8000000000000000
    cmp r12, r10
    jne .check_range
    inc r13d                       ; the first normal after the subnormals
    jmp .check_range
.extended_carry:
    mov r12, 0x8000000000000000
    inc r13d
    jmp .check_range

.shrink:
    cmp ebx, 2
    je .extended_shrink
    dec r12
    jmp .check_range
.extended_shrink:
    mov r10, 0x8000000000000000
    cmp r12, r10
    je .extended_borrow
    dec r12
    jmp .check_range
.extended_borrow:
    dec r13d
    mov r12, -1
    test r13d, 0x7fff
    jnz .check_range
    shr r12, 1                    ; the last subnormal before the normals

.check_range:
    test ebx, ebx
    jz .single_range
    cmp ebx, 1
    je .double_range
    mov ecx, r13d
    and ecx, 0x7fff
    jz .underflow
    cmp ecx, 0x7fff
    je .overflow
    jmp .original
.double_range:
    mov rcx, r12
    shl rcx, 1
    shr rcx, 53
    jz .underflow
    cmp ecx, 0x7ff
    je .overflow
    jmp .original
.single_range:
    mov ecx, r12d
    and ecx, 0x7f800000
    jz .underflow
    cmp ecx, 0x7f800000
    jne .original
.overflow:
    mov edi, 40
    jmp .range_effects
.underflow:
    mov edi, 48
.range_effects:
    mov esi, 34
    call __al_math_effects
    jmp .original

.quiet_y:
    cmp ebx, [rsp + 20]
    jne .convert_nan
    mov r12, r14
    mov r13d, r15d
.quiet_x:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    call __al_fp_quiet
    jmp .nan_result
.convert_nan:
    mov edi, ebx
    mov esi, 2
    mov edx, [rsp + 24]
    call __al_fp_special
.nan_result:
    mov r12, rax
    mov r13d, edx
    cmp dword [rsp + 28], 0
    je .original
    mov edi, 1
    xor esi, esi
    call __al_math_effects
.original:
    mov rax, r12
    mov edx, r13d
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
