; Original local-time inversion. Inputs: zone, normalized local seconds,
; and normalized DST preference (-1, 0, or 1). Return a POSIX timestamp.
bits 64
default rel

global __al_mktime_pick:function
extern __al_zone_lookup:function

section .text.__al_mktime_pick alloc exec nowrite progbits
__al_mktime_pick:
    test rdi, rdi
    jz .utc
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 72
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, [rbx + 64]          ; TZif type count
    xor r15d, r15d
    mov rax, 0x7fffffffffffffff
    mov [rsp], rax               ; earliest valid instant
    mov [rsp + 8], rax           ; earliest valid instant matching preference
    mov [rsp + 16], rax          ; forward gap instant
    mov [rsp + 24], rax          ; forward gap shift
    mov [rsp + 32], rax          ; gap instant matching preference
    mov [rsp + 40], rax          ; magnitude of matching gap shift

.next:
    cmp r15, r14
    jae .rule_offset
    mov rsi, [rbx + 32]
    mov rax, r15
    imul rax, 6
    mov eax, [rsi + rax]
    bswap eax
    movsxd rax, eax
    jmp .candidate
.rule_offset:
    mov rax, r15
    sub rax, r14
    cmp rax, [rbx + 104]         ; zero, one, or two rule offsets
    jae .choose
    mov rax, [rbx + rax*8 + 112]
.candidate:
    mov [rsp + 48], rax          ; proposed offset
    mov rsi, r12
    sub rsi, rax
    mov [rsp + 56], rsi          ; proposed UTC timestamp
    mov rdi, rbx
    call __al_zone_lookup
    cmp rax, [rsp + 48]
    jne .gap_probe
    mov rax, [rsp + 56]
    cmp rax, [rsp]
    jge .preferred_valid
    mov [rsp], rax
.preferred_valid:
    cmp rcx, r13
    jne .advance
    cmp rax, [rsp + 8]
    jge .advance
    mov [rsp + 8], rax
    jmp .advance

.gap_probe:
    ; Require both offsets to be active around this discontinuity.
    ; This excludes unrelated offsets from remote historical types.
    mov [rsp + 64], rax
    mov rsi, r12
    sub rsi, rax
    mov rdi, rbx
    call __al_zone_lookup
    cmp rax, [rsp + 48]
    jne .advance
    mov rdx, [rsp + 64]
    sub rdx, rax                 ; actual minus proposed offset
    mov rax, [rsp + 56]
    test rdx, rdx
    js .preferred_gap
    cmp rdx, [rsp + 24]
    jge .preferred_gap
    mov [rsp + 16], rax
    mov [rsp + 24], rdx
.preferred_gap:
    cmp rcx, r13
    jne .advance
    test rdx, rdx
    jns .gap_magnitude
    neg rdx
.gap_magnitude:
    cmp rdx, [rsp + 40]
    jge .advance
    mov [rsp + 32], rax
    mov [rsp + 40], rdx
.advance:
    inc r15
    jmp .next

.choose:
    mov rdx, 0x7fffffffffffffff
    mov rax, [rsp + 8]
    cmp rax, rdx
    jne .done
    mov rax, [rsp]
    cmp rax, rdx
    jne .done
    mov rax, [rsp + 32]
    cmp rax, rdx
    jne .done
    mov rax, [rsp + 16]
    cmp rax, rdx
    jne .done
    mov rdi, rbx
    mov rsi, r12
    call __al_zone_lookup
    sub r12, rax
    mov rax, r12
.done:
    add rsp, 72
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.utc:
    mov rax, rsi
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
