# Raw futex detector controls

The fixture links the shipped thread startup and private futex lock
objects. The linker wraps calls to the lock hooks. The wrappers forward
every call and annotate only the three fixture-owned lock words.
One word protects the shared counter. The other two synchronize each
worker's completion with the parent without ordering the two workers
with each other. The workers wait for process termination after
publishing completion, so the detector experiment isolates lock ordering
and data races from raw clear-TID lifecycle instrumentation.

Both detector runs require the locked counter to reach its exact
value and report zero errors. A separate unprotected run must report
a race at the counter's ELF address. A third run establishes opposite
lock acquisition orders. Helgrind must report the inversion for the two
fixture locks. DRD's run is recorded as clean because its role here is
race detection. Evidence binds the fixture binaries, client headers,
addresses, raw diagnostics, and exact exit status.

Native and Memcheck lifecycle gates independently verify the real lock
and thread behavior. This target measures the detector's view of the
named lock edges. Full-library annotations and stress have their own
acceptance scope.
