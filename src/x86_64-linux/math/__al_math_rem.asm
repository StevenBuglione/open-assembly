; Compute a same-kind remainder. r9 is 0 for fmod, 1 for remainder, or the remquo output pointer.
bits 64
default rel

global __al_math_rem:function
extern __al_fp_decode:function
extern __al_fp_pack_exact:function
extern __al_fp_quiet:function
extern __al_math_effects:function
extern __al_fp_special:function

section .text.__al_math_rem alloc exec nowrite progbits
__al_math_rem:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48
    mov ebx, edi
    mov r12, rsi
    mov r13d, edx
    mov r14, rcx
    mov r15d, r8d
    mov [rsp], r9
    cmp r9, 1
    jbe .decode_x
    mov dword [r9], 0
.decode_x:
    call __al_fp_decode
    mov [rsp + 8], r8d           ; x class
    mov [rsp + 12], ecx          ; x sign
    mov [rsp + 16], rax          ; x significand
    mov [rsp + 24], edx          ; x exponent

    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    call __al_fp_decode
    mov [rsp + 28], ecx          ; y sign
    cmp dword [rsp + 8], 5
    je .signaling
    cmp r8d, 5
    je .signaling_y
    cmp dword [rsp + 8], 4
    je .original
    cmp r8d, 4
    je .return_y
    cmp dword [rsp + 8], 3
    je .domain
    test r8d, r8d
    jz .domain
    cmp r8d, 3
    je .original
    cmp dword [rsp + 8], 0
    je .original

    ; Normalize to the format's highest significand bit before division.
    mov r11d, 23
    test ebx, ebx
    jz .normalize_y
    mov r11d, 52
    cmp ebx, 1
    je .normalize_y
    mov r11d, 63
.normalize_y:
    bsr r9, rax
    mov ecx, r11d
    sub ecx, r9d
    sub edx, ecx
    shl rax, cl
    mov r10, rax
    mov r14d, edx               ; exponent of normalized y
    mov rax, [rsp + 16]
    bsr r9, rax
    mov ecx, r11d
    sub ecx, r9d
    shl rax, cl
    mov r15d, [rsp + 24]
    sub r15d, ecx               ; exponent of normalized x
    mov edx, r15d
    sub edx, r14d
    xor r11d, r11d              ; quotient bits
    test edx, edx
    js .small_ratio

    ; Binary long division. An extra carry from doubling means that the
    ; next trial remainder is greater than any normalized divisor.
.divide:
    shl r11d, 1
    cmp rax, r10
    jb .next_digit
.subtract:
    sub rax, r10
    or r11d, 1
.next_digit:
    test edx, edx
    jz .round_quotient
    dec edx
    add rax, rax
    jnc .divide
    shl r11d, 1
    jmp .subtract

.round_quotient:
    mov r15d, r14d
    cmp qword [rsp], 0
    je .pack
    mov rdx, r10
    sub rdx, rax
    cmp rax, rdx
    ja .nearest_higher
    jb .pack
    test r11d, 1
    jz .pack
.nearest_higher:
    mov rax, rdx
    inc r11d
    xor dword [rsp + 12], 1
    jmp .pack

.small_ratio:
    cmp qword [rsp], 0
    je .original
    cmp edx, -1
    jne .original
    cmp rax, r10
    jbe .original
    ; 1/2 < |x/y| < 1. The unsigned subtraction includes a possible
    ; doubled-divisor carry, and the resulting magnitude fits 64 bits.
    add r10, r10
    sub r10, rax
    mov rax, r10
    mov r11d, 1
    xor dword [rsp + 12], 1
.pack:
    mov rsi, rax
    mov r9, [rsp]
    cmp r9, 1
    jbe .return_finite
    and r11d, 127
    mov edx, [rsp + 28]
    mov ecx, r13d
    test ebx, ebx
    jz .single_quotient_sign
    cmp ebx, 1
    je .double_quotient_sign
    shr ecx, 15
    jmp .store_quotient
.single_quotient_sign:
    mov ecx, r12d
    shr ecx, 31
    jmp .store_quotient
.double_quotient_sign:
    mov rcx, r12
    shr rcx, 63
.store_quotient:
    cmp edx, ecx
    je .quotient_positive
    neg r11d
.quotient_positive:
    mov [r9], r11d
.return_finite:
    mov edi, ebx
    mov edx, r15d
    mov ecx, [rsp + 12]
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
.signaling_y:
    mov r12, r14
    mov r13d, r15d
.signaling:
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
.return_y:
    mov r12, r14
    mov r13d, r15d
.original:
    mov rax, r12
    mov edx, r13d
.done:
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
