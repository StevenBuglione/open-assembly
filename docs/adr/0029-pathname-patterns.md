# Pathname component matching

Fnmatch uses the POSIX shell pattern syntax with *, ?, bracket
lists and ranges, POSIX character classes, single-character
collating symbols and equivalence classes, and backslash
escaping. Either ! or ^ at the start of a bracket list
negates it. An unclosed bracket is a literal opening bracket.
A trailing backslash is literal. If quoting a closing bracket
leaves the list unclosed, the list can use that closing bracket
with a literal backslash. A malformed or unknown character class
returns FNM_NOMATCH.

FNM_PATHNAME prevents wildcards and brackets from matching a
slash. FNM_PERIOD requires an explicit leading period at the
start of the string and, with FNM_PATHNAME, at each component.
FNM_NOESCAPE treats a backslash as literal. FNM_CASEFOLD and
its alias FNM_IGNORECASE fold literal comparisons using the
locale upper and lower mappings. A range can match the original
scalar range or the range of folded scalars. Character classes
apply to the original scalar. A match returns zero. Other results return FNM_NOMATCH and preserve errno.

The C locale compares byte values and applies its ASCII
character classes. C.UTF-8 matches complete UTF-8 scalars,
orders ranges by scalar value and uses the project's wide
classes. Invalid UTF-8 bytes compare as distinct opaque
units. Matching uses a single saved star retry position and
requires no heap allocation.

[POSIX fnmatch](https://pubs.opengroup.org/onlinepubs/9799919799/functions/fnmatch.html).
