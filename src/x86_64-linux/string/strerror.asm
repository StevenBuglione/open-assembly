; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strerror
; header: string.h
; prototype: char *strerror(int error)
; standard: C17 7.24.6.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:errno-message-contract
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Return a nonempty NUL-terminated C-locale message for the supplied number.
; semantics: Unassigned numbers and zero use No error information. The returned storage is immutable and remains valid.
; semantics: Do not change errno. Message wording is implementation-defined.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strerror:function

section .text.strerror alloc exec nowrite progbits
strerror:
    movsxd rdi, edi
    cmp rdi, 134                  ; last Linux errno in the table
    ja .fallback
    lea rax, [rel messages]
    test edi, edi
    jz .done
.skip_byte:
    cmp byte [rax], 0
    lea rax, [rax + 1]             ; advance without changing the comparison
    jne .skip_byte
    dec rdi
    jnz .skip_byte
    cmp byte [rax], 0              ; unused errno number inside the table
    je .fallback
.done:
    ret
.fallback:
    lea rax, [rel messages]
    ret

section .rodata.strerror alloc noexec nowrite progbits
messages:
    db "No error information", 0                             ; 0 NONE
    db "Operation is not permitted", 0                       ; 1 EPERM
    db "File or directory does not exist", 0                 ; 2 ENOENT
    db "Process does not exist", 0                           ; 3 ESRCH
    db "Interrupted by a signal", 0                          ; 4 EINTR
    db "Input or output failed", 0                           ; 5 EIO
    db "Device or address is unavailable", 0                 ; 6 ENXIO
    db "Too many argument bytes", 0                          ; 7 E2BIG
    db "Executable format is invalid", 0                     ; 8 ENOEXEC
    db "File descriptor is invalid", 0                       ; 9 EBADF
    db "No child process is available", 0                    ; 10 ECHILD
    db "Resource temporarily unavailable", 0                 ; 11 EAGAIN
    db "Memory allocation failed", 0                         ; 12 ENOMEM
    db "Access is denied", 0                                 ; 13 EACCES
    db "Address cannot be accessed", 0                       ; 14 EFAULT
    db "Operation requires a block device", 0                ; 15 ENOTBLK
    db "Resource is busy", 0                                 ; 16 EBUSY
    db "File already exists", 0                              ; 17 EEXIST
    db "Operation crosses device boundaries", 0              ; 18 EXDEV
    db "Device is unavailable", 0                            ; 19 ENODEV
    db "A path component is not a directory", 0              ; 20 ENOTDIR
    db "Operation cannot be performed on a directory", 0     ; 21 EISDIR
    db "Argument is invalid", 0                              ; 22 EINVAL
    db "System file table is full", 0                        ; 23 ENFILE
    db "Process file descriptor limit reached", 0            ; 24 EMFILE
    db "Device does not support this control operation", 0   ; 25 ENOTTY
    db "Executable file is busy", 0                          ; 26 ETXTBSY
    db "File exceeds the size limit", 0                      ; 27 EFBIG
    db "Device has insufficient space", 0                    ; 28 ENOSPC
    db "Descriptor does not support seeking", 0              ; 29 ESPIPE
    db "Filesystem is read-only", 0                          ; 30 EROFS
    db "File has reached its link limit", 0                  ; 31 EMLINK
    db "Pipe has no reader", 0                               ; 32 EPIPE
    db "Argument is outside the mathematical domain", 0      ; 33 EDOM
    db "Result is outside the representable range", 0        ; 34 ERANGE
    db "Operation would deadlock", 0                         ; 35 EDEADLK
    db "Path or name exceeds the length limit", 0            ; 36 ENAMETOOLONG
    db "File lock resources are exhausted", 0                ; 37 ENOLCK
    db "System call is unavailable", 0                       ; 38 ENOSYS
    db "Directory contains entries", 0                       ; 39 ENOTEMPTY
    db "Symbolic link traversal limit reached", 0            ; 40 ELOOP
    db 0                                                     ; 41 UNUSED
    db "Requested message type is unavailable", 0            ; 42 ENOMSG
    db "Identifier has been removed", 0                      ; 43 EIDRM
    db "Channel number exceeds the supported range", 0       ; 44 ECHRNG
    db "Link level two lost synchronization", 0              ; 45 EL2NSYNC
    db "Link level three stopped", 0                         ; 46 EL3HLT
    db "Link level three was reset", 0                       ; 47 EL3RST
    db "Link number exceeds the supported range", 0          ; 48 ELNRNG
    db "Protocol driver is detached", 0                      ; 49 EUNATCH
    db "CSI structure is unavailable", 0                     ; 50 ENOCSI
    db "Link level two stopped", 0                           ; 51 EL2HLT
    db "Exchange is invalid", 0                              ; 52 EBADE
    db "Request descriptor is invalid", 0                    ; 53 EBADR
    db "Exchange capacity reached", 0                        ; 54 EXFULL
    db "Anode is unavailable", 0                             ; 55 ENOANO
    db "Request code is invalid", 0                          ; 56 EBADRQC
    db "Slot is invalid", 0                                  ; 57 EBADSLT
    db 0                                                     ; 58 UNUSED
    db "Font file has an invalid format", 0                  ; 59 EBFONT
    db "Device does not provide a stream", 0                 ; 60 ENOSTR
    db "Requested data is unavailable", 0                    ; 61 ENODATA
    db "Timer has expired", 0                                ; 62 ETIME
    db "Stream resources are exhausted", 0                   ; 63 ENOSR
    db "Machine is offline", 0                               ; 64 ENONET
    db "Required package is missing", 0                      ; 65 ENOPKG
    db "Object is on a remote system", 0                     ; 66 EREMOTE
    db "Link has disconnected", 0                            ; 67 ENOLINK
    db "Resource advertisement failed", 0                    ; 68 EADV
    db "Remote mount failed", 0                              ; 69 ESRMNT
    db "Sending data failed", 0                              ; 70 ECOMM
    db "Protocol operation failed", 0                        ; 71 EPROTO
    db "Operation would span multiple remote hops", 0        ; 72 EMULTIHOP
    db "Remote filesystem operation failed", 0               ; 73 EDOTDOT
    db "Message is invalid", 0                               ; 74 EBADMSG
    db "Value does not fit its destination type", 0          ; 75 EOVERFLOW
    db "Network name is ambiguous", 0                        ; 76 ENOTUNIQ
    db "Descriptor is in the wrong state", 0                 ; 77 EBADFD
    db "Remote address has changed", 0                       ; 78 EREMCHG
    db "Required shared library cannot be accessed", 0       ; 79 ELIBACC
    db "Shared library is damaged", 0                        ; 80 ELIBBAD
    db "Executable library section is damaged", 0            ; 81 ELIBSCN
    db "Shared library count exceeds the limit", 0           ; 82 ELIBMAX
    db "Shared library cannot be started as a program", 0    ; 83 ELIBEXEC
    db "Byte sequence is invalid for the encoding", 0        ; 84 EILSEQ
    db "Interrupted operation requires restart", 0           ; 85 ERESTART
    db "Stream pipe failed", 0                               ; 86 ESTRPIPE
    db "User count exceeds the limit", 0                     ; 87 EUSERS
    db "Descriptor does not refer to a socket", 0            ; 88 ENOTSOCK
    db "Operation needs a destination address", 0            ; 89 EDESTADDRREQ
    db "Message exceeds the size limit", 0                   ; 90 EMSGSIZE
    db "Protocol and socket type do not match", 0            ; 91 EPROTOTYPE
    db "Protocol option is unavailable", 0                   ; 92 ENOPROTOOPT
    db "Protocol is unsupported", 0                          ; 93 EPROTONOSUPPORT
    db "Socket type is unsupported", 0                       ; 94 ESOCKTNOSUPPORT
    db "Operation is unsupported", 0                         ; 95 EOPNOTSUPP
    db "Protocol family is unsupported", 0                   ; 96 EPFNOSUPPORT
    db "Address family is unsupported", 0                    ; 97 EAFNOSUPPORT
    db "Address is in use", 0                                ; 98 EADDRINUSE
    db "Requested address is unavailable", 0                 ; 99 EADDRNOTAVAIL
    db "Network is offline", 0                               ; 100 ENETDOWN
    db "Network cannot be reached", 0                        ; 101 ENETUNREACH
    db "Network reset interrupted the connection", 0         ; 102 ENETRESET
    db "Connection was aborted locally", 0                   ; 103 ECONNABORTED
    db "Peer reset the connection", 0                        ; 104 ECONNRESET
    db "Buffer resources are exhausted", 0                   ; 105 ENOBUFS
    db "Socket already has a connection", 0                  ; 106 EISCONN
    db "Socket lacks a connection", 0                        ; 107 ENOTCONN
    db "Socket was shut down", 0                             ; 108 ESHUTDOWN
    db "Reference count exceeds the limit", 0                ; 109 ETOOMANYREFS
    db "Operation exceeded its time limit", 0                ; 110 ETIMEDOUT
    db "Peer refused the connection", 0                      ; 111 ECONNREFUSED
    db "Host is offline", 0                                  ; 112 EHOSTDOWN
    db "Host cannot be reached", 0                           ; 113 EHOSTUNREACH
    db "Operation is already underway", 0                    ; 114 EALREADY
    db "Operation has started and is pending", 0             ; 115 EINPROGRESS
    db "File handle no longer identifies a live object", 0   ; 116 ESTALE
    db "Filesystem metadata requires repair", 0              ; 117 EUCLEAN
    db "File lacks the required named type", 0               ; 118 ENOTNAM
    db "Named semaphore resources are unavailable", 0        ; 119 ENAVAIL
    db "File has the named type", 0                          ; 120 EISNAM
    db "Remote input or output failed", 0                    ; 121 EREMOTEIO
    db "Storage quota exceeded", 0                           ; 122 EDQUOT
    db "Device has no medium", 0                             ; 123 ENOMEDIUM
    db "Medium type is incompatible", 0                      ; 124 EMEDIUMTYPE
    db "Operation was canceled", 0                           ; 125 ECANCELED
    db "Required key is unavailable", 0                      ; 126 ENOKEY
    db "Key is past its expiration time", 0                  ; 127 EKEYEXPIRED
    db "Key was revoked", 0                                  ; 128 EKEYREVOKED
    db "Service rejected the key", 0                         ; 129 EKEYREJECTED
    db "Resource owner terminated", 0                        ; 130 EOWNERDEAD
    db "Resource state cannot be recovered", 0               ; 131 ENOTRECOVERABLE
    db "Radio transmission is disabled", 0                   ; 132 ERFKILL
    db "Memory hardware reported an error", 0                ; 133 EHWPOISON
    db "File type is incompatible with the operation", 0     ; 134 EFTYPE

section .note.GNU-stack noalloc noexec nowrite progbits
