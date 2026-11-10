# Linux exec replacement fixtures

The original process and PATH manifests retain their directed checks and
generated stubs. The supplemental ABI cases capture the signed 32-bit
failure result and check exact errno, caller vector contents, process identity,
and the shared SysV control state. The existing successful execve case
continues to check close-on-exec and inherited descriptors.

The shared packet harness installs three controlled static executable copies
in its temporary directory. A raw fork child calls the selected public exec
function. A replaced image must observe a reset data marker, the same
kernel PID, the exact argument and environment vectors, and the actual
executable identity from procfs. The failure arm checks that the same child
still owns the vectors and reports its actual return and errno. The parent
collects the private report, compares the raw wait status, and reaps the
child. Bounded polling and a parent-death signal protect failed runs.
[Linux execve](https://man7.org/linux/man-pages/man2/execve.2.html) · [Linux executable identity](https://man7.org/linux/man-pages/man5/proc_pid_exe.5.html)

Each input has two little-endian uint64 words. Each output has eight words
for the normalized no-return or signed failure result, errno, raw wait
status, scenario, image index, argument digest, environment digest, and
replacement or failure witness. The PID is verified locally and excluded
from the argument digest. Each digest starts at 1 and accumulates each
string byte including its NUL as value times 257 plus byte modulo 2^64.

The direct calls distinguish the pathname from PATH search. The search
cases cover ordered components, permission denial, empty components,
explicit slashes, loops, and absent names. The existing separate PATH
tests retain the known shell fallback and oversized-component differences
with pinned hosted libraries. [Linux exec family](https://man7.org/linux/man-pages/man3/exec.3.html)

ABI statuses 11–13 identify machine-state, return/errno, and caller
preservation failures. Packet statuses 21–23 identify return/errno,
image/exit, and vector/evidence mismatches. Statuses 31–35 identify
child argument, environment, procfs image, replacement identity, and
failure-preservation mismatches. Statuses in the 90s identify harness,
transport, timeout, signal death, or cleanup failures.

The project-only execvp allocation witness denies one request and then retries
a real search with both candidate directories absent. It checks ENOMEM and
ENOENT respectively, balances each real allocation and release, and checks
the original argument and environment vectors. Statuses 41–44 identify these
semantic rejections.
