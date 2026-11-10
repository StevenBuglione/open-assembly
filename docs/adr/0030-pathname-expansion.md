# Pathname expansion

Glob expands POSIX patterns component by component. Directory
names are matched using fnmatch, the active character encoding,
and explicit leading periods. Literal components are looked up
directly. A trailing slash requires a directory. GLOB_MARK adds
a slash to directory matches, including links to directories.
A dangling symbolic link can match without a trailing slash.

The result contains gl_pathc, gl_pathv, and gl_offs, with one
terminating null pointer and GLOB_DOOFFS null slots before the
first match. GLOB_APPEND retains the previous batch. Sorting
uses strcoll within each new batch unless GLOB_NOSORT is set.
GLOB_NOCHECK returns the original pattern if it has no matches.
Globfree releases all owned strings and the vector.

Nondirectory branches are skipped. Errors opening or reading
a directory, including an absent named directory, invoke the
supplied callback.
GLOB_ERR or a nonzero callback result stops the scan with
GLOB_ABORTED. The result still owns earlier matches. Allocation
failure returns GLOB_NOSPACE and retains results already stored.
A successful call or GLOB_NOMATCH preserves incoming errno.
Traversal uses heap frames and closes all opened directories.
Pinned glibc also skips nondirectory prefixes. Pinned musl can
report ENOTDIR for an explicitly named nondirectory prefix.

[POSIX glob](https://pubs.opengroup.org/onlinepubs/9799919799/functions/glob.html).
