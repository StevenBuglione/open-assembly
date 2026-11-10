; Execute the compiled program with call-owned states. At each start the
; visited set and alternative stack preserve all distinguishable captures.
bits 64
default rel

global __al_regex_exec:function
extern __al_fnmatch_unit:function
extern __al_regex_bracket:function
extern __al_regex_backref:function
extern __al_regex_seen:function
extern __al_regex_push:function
extern __al_regex_better:function
extern memset:function
extern memcpy:function

section .text.__al_regex_exec alloc exec nowrite progbits
__al_regex_exec:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r14, [rbx + 56]
    mov r15d, [rbx + 36]
.start:
    mov r12, [rbx + 40]
    mov rax, [rbx]
    mov r13, [rax + 8]
    mov qword [rbx + 48], 0
    mov qword [rbx + 104], 0
    mov rdi, r14
    mov esi, -1
    mov rdx, [rbx + 64]
    call memset
.step:
    mov rdi, rbx
    mov rsi, r13
    mov rdx, r12
    call __al_regex_seen
    cmp eax, 1
    je .backtrack
    test eax, eax
    jnz .return
    mov eax, [r13]
    cmp eax, 6
    jbe .operand
    cmp eax, 7
    je .jump
    cmp eax, 8
    je .split
    cmp eax, 9
    je .open
    cmp eax, 10
    je .close
    jmp .repetition
.operand:
    test eax, eax
    jz .match
    cmp eax, 1
    je .character
    cmp eax, 2
    je .dot
    cmp eax, 3
    je .bracket
    cmp eax, 4
    je .beginning
    cmp eax, 5
    je .ending
    jmp .reference
.character:
    cmp byte [r12], 0
    je .backtrack
    mov rdi, r12
    mov esi, r15d
    call __al_fnmatch_unit
    cmp eax, [r13 + 8]
    jne .backtrack
    jmp .consume
.dot:
    movzx eax, byte [r12]
    test eax, eax
    jz .backtrack
    cmp eax, 10
    jne .dot_unit
    test r15d, 4
    jnz .backtrack
.dot_unit:
    mov rdi, r12
    mov esi, r15d
    and esi, 1
    call __al_fnmatch_unit
    jmp .consume
.bracket:
    cmp byte [r12], 0
    je .backtrack
    mov rdi, r12
    mov esi, r15d
    call __al_fnmatch_unit
    mov [rsp], rdx
    mov rdi, [r13 + 8]
    mov esi, ecx
    mov edx, eax
    mov ecx, r15d
    call __al_regex_bracket
    test rax, rax
    jz .pattern_error
    test edx, edx
    jz .backtrack
    mov rdx, [rsp]
.consume:
    add r12, rdx
    jmp .advance
.beginning:
    cmp r12, [rbx + 8]
    jne .after_newline
    test dword [rbx + 32], 1   ; REG_NOTBOL
    jnz .backtrack
    jmp .advance
.after_newline:
    test r15d, 4
    jz .backtrack
    cmp byte [r12 - 1], 10
    jne .backtrack
    jmp .advance
.ending:
    movzx eax, byte [r12]
    test eax, eax
    jnz .before_newline
    test dword [rbx + 32], 2   ; REG_NOTEOL
    jnz .backtrack
    jmp .advance
.before_newline:
    cmp eax, 10
    jne .backtrack
    test r15d, 4
    jz .backtrack
    jmp .advance
.reference:
    mov rax, [r13 + 8]
    shl rax, 4
    mov rdi, [r14 + rax]
    mov rsi, [r14 + rax + 8]
    mov rdx, r12
    mov ecx, r15d
    call __al_regex_backref
    test rax, rax
    jz .backtrack
    mov r12, rax
    jmp .advance
.jump:
    mov r13, [r13 + 8]
    jmp .step
.split:
    mov rdi, rbx
    mov rsi, [r13 + 8]
    mov rdx, r12
    call __al_regex_push
    test eax, eax
    jnz .return
    jmp .advance
.open:
    cmp qword [rbx + 72], 0
    je .advance
    mov rcx, [r13 + 8]
    shl rcx, 4
    lea rdi, [r14 + rcx]
    mov [rdi], r12
    mov qword [rdi + 8], -1
    mov rdx, [r13 + 16]
    sub rdx, [r13 + 8]
    jz .advance
    shl rdx, 4                 ; descendants belong to this participation
    add rdi, 16
    mov esi, -1
    call memset
    jmp .advance
.close:
    cmp qword [rbx + 72], 0
    je .advance
    mov rax, [r13 + 8]
    shl rax, 4
    mov [r14 + rax + 8], r12
    jmp .advance
.repetition:
    mov ecx, [r13 + 4]
    shl rcx, 4
    add rcx, [rbx + 72]
    lea r8, [r14 + rcx]
    cmp eax, 11
    je .repeat_init
    cmp eax, 12
    je .repeat_split
    cmp eax, 13
    je .repeat_next
    mov qword [r8], -1         ; REPEAT_END clears inactive state
    mov qword [r8 + 8], -1
    jmp .advance
.repeat_init:
    mov qword [r8], 0
    mov qword [r8 + 8], 0
    jmp .advance
.repeat_split:
    mov rax, [r8]
    cmp rax, [r13 + 24]
    jae .jump                  ; upper bound exhausted
    cmp rax, [r13 + 16]
    jb .repeat_body
    mov [rsp + 8], r8
    mov rdi, rbx
    mov rsi, [r13 + 8]
    mov rdx, r12
    call __al_regex_push
    test eax, eax
    jnz .return
    mov r8, [rsp + 8]
.repeat_body:
    mov [r8 + 8], r12
    jmp .advance
.repeat_next:
    mov rcx, [r13 + 8]         ; corresponding REPEAT_SPLIT
    mov rax, [r8]
    inc rax
    cmp qword [rcx + 24], -1
    jne .counted
    cmp rax, [rcx + 16]
    jbe .counted
    mov rax, [rcx + 16]        ; unbounded counts saturate at the minimum
.counted:
    mov [r8], rax
    cmp r12, [r8 + 8]
    jne .repeat_again
    cmp rax, [rcx + 16]
    jb .repeat_again
    mov r13, [rcx + 8]         ; a zero-width iteration made no progress
    jmp .step
.repeat_again:
    mov qword [r8 + 8], 0
    mov r13, rcx
    jmp .step
.advance:
    add r13, 32
    jmp .step
.match:
    cmp qword [rbx + 16], 0
    je .success
    cmp r12, [rbx + 48]
    jb .backtrack
    ja .record
    mov rdi, r14
    mov rsi, [rbx + 80]
    mov rdx, [rbx + 72]
    mov ecx, r15d
    call __al_regex_better
    test eax, eax
    jz .backtrack
.record:
    mov [rbx + 48], r12
    mov rdi, [rbx + 80]
    mov rsi, r14
    mov rdx, [rbx + 72]
    call memcpy
    mov rax, [rbx + 80]
    mov rcx, [rbx + 40]
    mov [rax], rcx
    mov [rax + 8], r12
.backtrack:
    mov rax, [rbx + 104]
    test rax, rax
    jz .start_complete
    sub rax, [rbx + 112]
    mov [rbx + 104], rax
    add rax, [rbx + 88]
    mov r13, [rax]
    mov r12, [rax + 8]
    mov rdi, r14
    lea rsi, [rax + 16]
    mov rdx, [rbx + 64]
    call memcpy
    jmp .step
.start_complete:
    cmp qword [rbx + 48], 0
    jne .success
    mov rdi, [rbx + 40]
    cmp byte [rdi], 0
    je .no_match
    mov esi, r15d
    and esi, 1
    call __al_fnmatch_unit
    add [rbx + 40], rdx
    jmp .start
.success:
    xor eax, eax
    jmp .return
.no_match:
    mov eax, 1                 ; REG_NOMATCH
    jmp .return
.pattern_error:
    mov eax, edx
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
