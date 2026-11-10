# Open POSIX thread subset

The fixture source is Linux Test Project release 20260930 at commit
`2279d708c817db657611a30c427c7d06c4360049`. The manifest pins the
compressed archive, its license notice, the upstream support header, and
each selected test. The upstream notice distinguishes GPLv2-or-later
legacy tests from BSD-2-Clause additions. The selected files identify
their original GPL licensing. The gate compiles their bytes directly
from the pinned archive. It publishes only reports and artifact hashes.
[Official release](https://github.com/linux-test-project/ltp/releases/tag/20260930)

The selected tests cover the shared process ID, default joinability,
start-argument and result transport, explicit thread exit through join,
and thread handle identity. They use the current pthread subset and
existing runtime APIs. Cases that require additional pthread features
or reuse expired handles stay outside this selection. The separate
lifecycle gate covers detach and TCB reclamation directly.
