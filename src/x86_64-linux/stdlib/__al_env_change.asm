; Original shared environment mutator.
; rdi = name or putenv string, rsi = value, rdx = operation, rcx = overwrite.
; Operations: 0 setenv, 1 unsetenv, 2 putenv. Returns 0 or -1 with errno.
bits 64
default rel

global __al_env_change:function
global __al_env_owned:data
extern environ:data
extern __al_env_lock:data
extern __al_lock:function
extern __al_unlock:function
extern __al_env_name:function
extern __al_env_match:function
extern __al_env_collect:function
extern __errno_location:function
extern malloc:function
extern free:function
extern strlen:function
extern memcpy:function

section .text.__al_env_change alloc exec nowrite progbits
__al_env_change:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 72
    mov rbx, rdi                  ; key bytes, or the entire putenv string
    mov r12, rsi                  ; value to copy for setenv
    mov r13, rdx                  ; operation
    mov r14, rcx                  ; setenv overwrite flag
    mov qword [rsp + 16], 0       ; matching array slot
    mov qword [rsp + 32], 0       ; uncommitted owned string node

    xor esi, esi
    cmp r13, 2
    jne .validate
    mov esi, 1                    ; putenv allows the name=value separator
.validate:
    call __al_env_name
    test rax, rax
    jz .invalid
    mov r15, rax                  ; key length
    cmp r13, 2
    jne .validate_value
    test rdx, rdx
    jnz .lock
    mov r13d, 1                   ; putenv(name) removes the name
    jmp .lock
.validate_value:
    test r13, r13
    jnz .lock
    test r12, r12
    jz .invalid

.lock:
    lea rdi, [rel __al_env_lock]
    call __al_lock
    mov rax, [rel environ]
    mov [rsp], rax                ; active vector may be caller-supplied
    cmp r13, 1
    je .remove
    mov [rsp + 8], rax            ; scan cursor or append position
    test rax, rax
    jz .make_entry
.find:
    mov rax, [rsp + 8]
    mov rdi, [rax]
    test rdi, rdi
    jz .make_entry
    mov rsi, rbx
    mov rdx, r15
    call __al_env_match
    test rax, rax
    jnz .found
    add qword [rsp + 8], 8
    jmp .find
.found:
    mov rax, [rsp + 8]
    mov [rsp + 16], rax
    cmp r13, 2
    je .make_entry
    test r14, r14
    jz .success

.make_entry:
    cmp r13, 2
    je .borrow_entry
    mov rdi, r12
    call strlen
    inc rax                      ; include the value terminator
    jz .no_memory
    mov [rsp + 64], rax
    mov rdi, r15
    add rdi, 17                  ; node header and equals separator
    jc .no_memory
    add rdi, rax
    jc .no_memory
    mov [rsp + 40], rdi           ; complete node byte count
    call malloc
    test rax, rax
    jz .no_memory
    mov [rsp + 32], rax
    mov rdx, [rsp + 40]
    sub rdx, 16
    mov [rax + 8], rdx            ; installed string storage length
    lea rdi, [rax + 16]
    mov [rsp + 24], rdi           ; string follows the ownership header
    mov rsi, rbx
    mov rdx, r15
    call memcpy
    mov rdi, [rsp + 24]
    mov byte [rdi + r15], 61      ; '='
    lea rdi, [rdi + r15 + 1]
    mov rsi, r12
    mov rdx, [rsp + 64]
    call memcpy
    jmp .place_entry
.borrow_entry:
    mov [rsp + 24], rbx           ; putenv keeps the actual caller pointer

.place_entry:
    mov rax, [rsp + 16]
    test rax, rax
    jz .append
    mov rdx, [rsp + 24]
    mov [rax], rdx
    jmp .commit
.append:
    mov rcx, [rsp + 8]
    sub rcx, [rsp]
    shr rcx, 3                   ; existing entry count
    mov [rsp + 48], rcx
    mov rdx, rcx
    add rdx, 2                   ; new entry and terminator
    jc .no_memory
    mov rax, [rsp]
    test rax, rax
    jz .grow
    cmp rax, [rel owned_vector]
    jne .grow
    cmp rdx, [rel owned_capacity]
    ja .grow
    mov rdx, [rsp + 24]
    mov [rax + rcx*8], rdx
    mov qword [rax + rcx*8 + 8], 0
    jmp .commit

.grow:
    ; Double the required slot count when that still fits a C object.
    mov rax, 0x0fffffffffffffff   ; PTRDIFF_MAX / sizeof(char *)
    cmp rdx, rax
    ja .no_memory
    lea rcx, [rdx + rdx]
    cmp rcx, rax
    ja .capacity
    mov rdx, rcx
.capacity:
    cmp rdx, 8
    jae .allocate_vector
    mov edx, 8
.allocate_vector:
    mov [rsp + 40], rdx
    lea rdi, [rdx*8]
    call malloc
    test rax, rax
    jz .no_memory
    mov [rsp + 56], rax
    mov rdx, [rsp + 48]
    test rdx, rdx
    jz .fill_new
    shl rdx, 3
    mov rdi, rax
    mov rsi, [rsp]
    call memcpy
.fill_new:
    mov rax, [rsp + 56]
    mov rcx, [rsp + 48]
    mov rdx, [rsp + 24]
    mov [rax + rcx*8], rdx
    mov qword [rax + rcx*8 + 8], 0
    mov rdi, [rel owned_vector]
    mov [rel owned_vector], rax
    mov rcx, [rsp + 40]
    mov [rel owned_capacity], rcx
    mov [rel environ], rax       ; all fallible work is complete
    test rdi, rdi
    jz .commit
    call free
.commit:
    mov rax, [rsp + 32]
    test rax, rax
    jz .collect
    mov rcx, [rel __al_env_owned]
    mov [rax], rcx
    mov [rel __al_env_owned], rax
    jmp .collect

.remove:
    test rax, rax
    jz .collect
    mov r12, rax                  ; read cursor
    mov r14, rax                  ; write cursor
.compact:
    mov rdi, [r12]
    test rdi, rdi
    jz .finish_remove
    mov rsi, rbx
    mov rdx, r15
    call __al_env_match
    test rax, rax
    jnz .advance
    mov rax, [r12]
    mov [r14], rax
    add r14, 8
.advance:
    add r12, 8
    jmp .compact
.finish_remove:
    mov qword [r14], 0
.collect:
    call __al_env_collect
.success:
    lea rdi, [rel __al_env_lock]
    call __al_unlock
    xor eax, eax
    jmp .done

.no_memory:
    mov rdi, [rsp + 32]
    test rdi, rdi
    jz .unlock_error
    call free
.unlock_error:
    lea rdi, [rel __al_env_lock]
    call __al_unlock
    mov r13d, 12                  ; ENOMEM
    jmp .report_error
.invalid:
    mov r13d, 22                  ; EINVAL
.report_error:
    call __errno_location
    mov [rax], r13d
    mov eax, -1
.done:
    add rsp, 72
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .bss.__al_env_change alloc noexec write nobits align=8
__al_env_owned:
    resq 1
owned_vector:
    resq 1
owned_capacity:
    resq 1

section .note.GNU-stack noalloc noexec nowrite progbits
