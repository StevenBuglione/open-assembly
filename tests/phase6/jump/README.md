# Independent Phase 6 nonlocal-jump fixtures

The C fixture uses valid C17 controlling expressions for setjmp, live
saved contexts, nested calls, and volatile state across a nonlocal jump.
It verifies zero-to-one return conversion, exact negative returns,
preserved current x87 and MXCSR controls, and the current ordinary signal
mask. The sigsetjmp and siglongjmp cases distinguish saved-mask restoration
from the no-save mode. Hosted glibc and musl checks compare these observable
results. Project-only checks also inspect the public mask-record layout.

The assembly fixture independently loads and saves all six System V
callee-saved registers. It compares the saved words to known values
and to the expected post-call stack pointer and return address. It then
clobbers those registers, changes the stack depth, and checks the exact
restored state after longjmp resumes the original call. This fixture
targets the project's public jmp_buf representation.

The generated save stubs leave canary-filled records untouched and are
rejected. The generated noreturn restore stubs exit with status zero
before emitting the required post-resume marker, so their rejections
are attributable to the missing resumed execution.

[Phase 6 jump ABI](../../../docs/adr/0007-linux-files-process-signal-time.md) ·
[WG14 C17 nonlocal jumps](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf) ·
[System V AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI)
