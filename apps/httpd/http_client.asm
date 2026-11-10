; Advance one nonblocking connection. Return one to retain it, zero to close.
; Slot layout: fd plus one, write-interest flag, input count, output pointer,
; output count, monotonic deadline, and 8192 input bytes.
bits 64
default rel

global __al_http_client:function
extern __al_http_find:function
extern __al_http_parse:function
extern __errno_location:function
extern epoll_ctl:function
extern recv:function
extern send:function

section .text.__al_http_client alloc exec nowrite progbits
__al_http_client:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi                ; client slot
    movsxd r12, esi             ; epoll descriptor
    mov r13d, edx               ; readiness mask
    mov r14, 5000000000         ; five seconds in monotonic nanoseconds
    add r14, rcx
    cmp qword [rbx + 16], 0
    jne .send
.receive:
    mov r15, [rbx + 8]
    mov edi, [rbx]
    dec edi
    lea rsi, [rbx + r15 + 40]
    mov edx, 8192
    sub rdx, r15
    xor ecx, ecx
    call recv
    test rax, rax
    js .receive_error
    jz .close
    mov [rbx + 32], r14
    add [rbx + 8], rax
    cmp r15, 3
    jb .scan_beginning
    sub r15, 3                  ; retain starts that cross the previous read
    jmp .scan
.scan_beginning:
    xor r15d, r15d
.scan:
    lea rdi, [rbx + r15 + 40]
    mov rsi, [rbx + 8]
    sub rsi, r15
    call __al_http_find
    test rax, rax
    jnz .parse
    cmp qword [rbx + 8], 8192
    jb .keep
    mov eax, 431
    jmp .response
.parse:
    lea rdi, [rbx + 40]
    lea rsi, [r15 + rax]
    call __al_http_parse
.response:
    movzx ecx, ax
    cmp ecx, 200
    je .ok
    cmp ecx, 404
    je .not_found
    cmp ecx, 405
    je .method_not_allowed
    cmp ecx, 431
    je .too_large
    lea rax, [rel bad_request]
    lea rdx, [rel bad_request_end]
    jmp .queue
.ok:
    lea rdx, [rel ok_end]
    test eax, 65536
    jz .ok_start
    lea rdx, [rel ok_headers_end]
.ok_start:
    lea rax, [rel ok]
    jmp .queue
.not_found:
    lea rax, [rel not_found]
    lea rdx, [rel not_found_end]
    jmp .queue
.method_not_allowed:
    lea rax, [rel method_not_allowed]
    lea rdx, [rel method_not_allowed_end]
    jmp .queue
.too_large:
    lea rax, [rel too_large]
    lea rdx, [rel too_large_end]
.queue:
    sub rdx, rax
    mov [rbx + 16], rax
    mov [rbx + 24], rdx
.send:
    mov edi, [rbx]
    dec edi
    mov rsi, [rbx + 16]
    mov rdx, [rbx + 24]
    mov ecx, 16384              ; MSG_NOSIGNAL
    call send
    test rax, rax
    js .send_error
    jz .close
    mov [rbx + 32], r14
    add [rbx + 16], rax
    sub [rbx + 24], rax
    jz .close
.watch_write:
    cmp dword [rbx + 4], 0
    jne .keep
    mov dword [rel write_event], 4  ; EPOLLOUT
    mov [rel write_event + 4], rbx
    mov edi, r12d
    mov esi, 3                  ; EPOLL_CTL_MOD
    mov edx, [rbx]
    dec edx
    lea rcx, [rel write_event]
    call epoll_ctl
    test eax, eax
    jnz .close
    mov dword [rbx + 4], 1
.keep:
    mov eax, 1
    jmp .return
.receive_error:
    call __errno_location
    mov eax, [rax]
    cmp eax, 4                  ; EINTR
    je .receive
    cmp eax, 11                 ; EAGAIN
    jne .close
    test r13d, 0x2018           ; EPOLLRDHUP | EPOLLHUP | EPOLLERR
    jz .keep
    jmp .close
.send_error:
    call __errno_location
    mov eax, [rax]
    cmp eax, 4                  ; EINTR
    je .send
    cmp eax, 11                 ; EAGAIN
    jne .close
    test r13d, 0x18             ; EPOLLHUP | EPOLLERR
    jz .watch_write
.close:
    xor eax, eax
.return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_http_client alloc noexec nowrite progbits
ok:
    db "HTTP/1.1 200 OK", 13, 10
    db "Connection: close", 13, 10
    db "Content-Type: text/plain", 13, 10
    db "Content-Length: 14", 13, 10, 13, 10
ok_headers_end:
    db "open-assembly", 10
ok_end:
bad_request:
    db "HTTP/1.1 400 Bad Request", 13, 10
    db "Connection: close", 13, 10
    db "Content-Length: 0", 13, 10, 13, 10
bad_request_end:
not_found:
    db "HTTP/1.1 404 Not Found", 13, 10
    db "Connection: close", 13, 10
    db "Content-Length: 0", 13, 10, 13, 10
not_found_end:
method_not_allowed:
    db "HTTP/1.1 405 Method Not Allowed", 13, 10
    db "Connection: close", 13, 10
    db "Allow: GET, HEAD", 13, 10
    db "Content-Length: 0", 13, 10, 13, 10
method_not_allowed_end:
too_large:
    db "HTTP/1.1 431 Request Header Fields Too Large", 13, 10
    db "Connection: close", 13, 10
    db "Content-Length: 0", 13, 10, 13, 10
too_large_end:

section .bss.__al_http_client alloc noexec write nobits align=8
write_event: resb 12

section .note.GNU-stack noalloc noexec nowrite progbits
