# Linux stat family verification fixtures

The original file-information manifest retains the layout tests, directed
cases and generated stubs. Each supplemental ABI test captures the signed
32-bit result, checks the shared SysV machine state, and compares errno and
the caller record on success and failure. The descriptor and flags checks
poison the upper halves of narrow argument registers.

Every timed case uses a test-owned directory, a regular file with controlled
attributes, and independent raw Linux calls. The fixture checks every named
field against the raw result, including inode and device identity, ownership,
block accounting, and all three timestamps. When a path selects the regular
file or directory, the fixture also verifies its raw identity using the
independently opened descriptor. Success requires intact surrounding guards
and cleared candidate padding. Errors preserve the entire caller record.

The two input words are little-endian uint64 values. The 64-byte output
holds signed result, errno and size, then unsigned scenario, mode, link count,
timestamp digest and precision mask. Directory and pipe size/link counts
are checked locally and omitted from cross-process comparisons. Regular
files emit the actual raw-verified atime and mtime using a polynomial with
multiplier 4294967311 modulo 2^64. Each precision bit records whether one
corresponding field matched the requested value. File systems can round
timestamp requests. Inode numbers, ctime, block use and other process-local
observations are checked against raw Linux before the packet is emitted.
[Linux timestamp precision](https://man7.org/linux/man-pages/man2/utimensat.2.html)

The scenario set covers ordinary, sparse, hard-linked and unlinked files,
symlinks and dangling links, directory and pipe descriptors, and closed
descriptors. Relative lookup distinguishes its directory from a current
directory decoy. Absolute lookup uses an invalid dirfd. The Linux
`AT_EMPTY_PATH` cases use an empty string and include an O_PATH symlink.
The published baseline is `fstat` and `newfstatat`.
[Project file ABI](../../../docs/adr/0007-linux-files-process-signal-time.md) ·
[Linux stat family](https://man7.org/linux/man-pages/man2/stat.2.html)

ABI statuses 11–14 identify machine state, result/errno, success record,
and failure atomicity. Packet statuses 21–23 identify result/errno, named
fields, and bounds or padding. The 90s identify fixture, raw oracle,
transport and cleanup failures.
