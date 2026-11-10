# Linux wait status fixtures

The original Phase 6 process manifest retains the directed tests and typed
zero-stub controls for `wait` and `waitpid`. The supplemental ABI cases
capture the signed 32-bit result, observe a guarded `int` status word, and
check errno and the shared SysV control state. The `waitpid` ABI case poisons
the upper halves of both narrow input registers while exercising a live
child, invalid options, a negative selector, and an empty child set.

The shared timed fixture accepts two little-endian uint64 words per input.
Each 64-byte output starts with three records of four int32 words. Each
record contains the selected result, raw Linux status, errno before, and
errno after. The last two uint64 words hold the scenario and initial options.
Unused records are zero. Positive PIDs are represented as 1 only after
checking exact equality with the child the fixture created. The original
zero and negative results, errno and raw status values remain exact.

A raw child holds on a pipe until the parent releases it or the child's
poll deadline expires. The child acknowledges readiness only after
installing a parent-death signal and closing inherited standard descriptors.
The two-child wait case releases only a child outside the parent group.
Before testing waitpid group selectors, a different-group child has a pending exit.
The tested operation must reap the matching child, and raw wait4 then reaps
the other child. The explicit group ID names a live leader distinct from both
the parent group and the selected PID. For stopped and continued children, raw waitid observes each
event with WNOWAIT before the tested waitpid consumes it. Raw cleanup reaps
all fixture children on the returning paths. [Linux wait and waitid](https://man7.org/linux/man-pages/man2/waitpid.2.html) · [Linux parent-death signal](https://man7.org/linux/man-pages/man2/PR_SET_PDEATHSIG.2const.html)

The separate interruption cases arm a periodic SIGALRM without SA_RESTART
while one child is held. They require an observed signal, EINTR, unchanged
status, and an independent raw reap after release.
[POSIX wait and waitpid](https://pubs.opengroup.org/onlinepubs/9799919799/functions/wait.html)

Semantic statuses 11–14 cover ABI state, return and errno, status guards,
and reaping. Packet statuses 21–23 cover result and errno, status and
guards, and reaping. Interruption statuses 31–32 cover the interrupted
return and the unchanged status and child state. Statuses in the 90s
identify fixture setup, timeout, cleanup or transport failures.
