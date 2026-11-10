; Encode scalar esi to rdi or discard, using the state at rdx. Return the byte count.
; ECX selects the encoding: zero current locale, one C, two UTF-8.
bits 64
default rel

global __al_mb_encode:function
extern __al_mb_error:function
extern __al_locale_flags:data

section .text.__al_mb_encode alloc exec nowrite progbits
__al_mb_encode:
    cmp dword [rdx + 4], 0
    jne .invalid
    cmp esi, 0x80
    jb .ascii
    test ecx, ecx
    jz .locale
    dec ecx
    jmp .encoding
.locale:
    mov ecx, [rel __al_locale_flags]
.encoding:
    test ecx, 1
    jz .invalid
    cmp esi, 0x10ffff
    ja .invalid
    cmp esi, 0xd800
    jb .width
    cmp esi, 0xdfff
    jbe .invalid
.width:
    cmp esi, 0x800
    jb .two
    cmp esi, 0x10000
    jb .three
    mov eax, 4
    test rdi, rdi
    jz .done
    mov ecx, esi
    and ecx, 0x3f
    or ecx, 0x80
    mov [rdi + 3], cl
    shr esi, 6
    mov ecx, esi
    and ecx, 0x3f
    or ecx, 0x80
    mov [rdi + 2], cl
    shr esi, 6
    mov ecx, esi
    and ecx, 0x3f
    or ecx, 0x80
    mov [rdi + 1], cl
    shr esi, 6
    or esi, 0xf0
    jmp .first
.three:
    mov eax, 3
    test rdi, rdi
    jz .done
    mov ecx, esi
    and ecx, 0x3f
    or ecx, 0x80
    mov [rdi + 2], cl
    shr esi, 6
    mov ecx, esi
    and ecx, 0x3f
    or ecx, 0x80
    mov [rdi + 1], cl
    shr esi, 6
    or esi, 0xe0
    jmp .first
.two:
    mov eax, 2
    test rdi, rdi
    jz .done
    mov ecx, esi
    and ecx, 0x3f
    or ecx, 0x80
    mov [rdi + 1], cl
    shr esi, 6
    or esi, 0xc0
    jmp .first
.ascii:
    mov eax, 1
    test rdi, rdi
    jz .done
.first:
    mov [rdi], sil
.done:
    mov qword [rdx], 0
    ret
.invalid:
    mov rdi, rdx
    sub rsp, 8
    call __al_mb_error
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
