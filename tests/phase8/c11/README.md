# Independent C11 thread fixtures

The 31 cases exercise all 25 C17 threads interfaces on native Linux,
QEMU user mode and Memcheck. Each public interface has a generated
typed stub control. The common behavior is also checked using pinned
glibc and musl.

The lifecycle cases check identity, TLS, handle publication before
callback entry, signed `int` result transport and adjacent output
canaries. The exit case requires the initial thread to print a line
after joining the worker. The detached worker publishes its two
mapped ranges under the project's TCB ABI. The fixture confirms
the mappings were present and observes every page become unmapped,
including the rounded final page of a non-page-multiple TLS extent.

Mutex and condition cases cover ownership, recursive release, the
different busy and timeout statuses, acquiring the mutex after a
condition timeout and predicate handoffs on signal and broadcast.
Key cases check isolation and repeated destructor calls. A contended
once case checks nested initialization and publication to returning
threads.

The designated syscall observer arms only around a selected test
call. It forces the first and second anonymous mappings to fail
with `ENOMEM`, checks the unchanged handle and releases a mapping
on partial creation, and injects a known interrupted sleep remainder
through aliased duration and output. The yield probe observes one
real Linux scheduler syscall. A separate unwrapped sleep measures
elapsed monotonic time and checks the candidate's remainder policy.
The manifest scopes project-specific diagnostics separately from
the host comparisons.

[C17 threads clauses, WG14 N2310](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)
