"""Run scoped Phase 10 runtime manifest verification."""

import argparse
from functools import partial
from pathlib import Path

from phase6 import execute_manifest_gate, phase6_inputs
from spec import ROOT, snapshot_inputs

SUITE = Path("tests/phase10")
ENDPOINTS = frozenset({
    "socket", "socketpair", "bind", "connect", "listen", "accept", "accept4", "getsockname",
    "getpeername", "setsockopt", "getsockopt", "shutdown", "send", "recv", "sendto", "recvfrom",
    "sendmsg", "recvmsg", "poll", "ppoll", "epoll_create", "epoll_create1", "epoll_ctl",
    "epoll_wait", "epoll_pwait",
})


INET = frozenset({"htons", "ntohs", "htonl", "ntohl", "inet_pton", "inet_ntop"})
NETDB = frozenset({"getaddrinfo", "freeaddrinfo", "gai_strerror", "getnameinfo"})
TERMINAL = frozenset({
    "tcgetattr", "tcsetattr", "cfgetispeed", "cfgetospeed", "cfsetispeed", "cfsetospeed",
    "tcdrain", "tcflow", "tcflush", "tcsendbreak", "tcgetsid",
})
SUITES = {
    "endpoints": (ENDPOINTS, (Path("tests/phase2/abi.asm"),), "0013-linux-sockets-readiness.md",
                  "Linux socket wrappers, poll and epoll, loopback-only network operations."),
    "inet": (INET, (), "0015-numeric-addresses.md",
             "Canonical numeric address codecs, seeded guard cases and full 16-bit byte-order sweeps."),
    "terminal": (TERMINAL, (Path("tests/phase2/abi.asm"),), "0024-linux-termios.md",
                 "Linux x86-64 terminal ABI and real PTY behavior. Physical serial break timing is outside scope."),
    "netdb": (NETDB, (), "0016-local-name-service.md",
              "Numeric and local file lookup, allocator failures, owned results and portable host observations."),
}


def inputs(contracts):
    hashes = phase6_inputs()
    hashes.update(snapshot_inputs(ROOT, contracts))
    return dict(sorted(hashes.items()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=SUITES, default="endpoints")
    scope = parser.parse_args().suite
    public, assembly, contract, limits = SUITES[scope]
    directory = SUITE / scope
    contracts = [Path("docs/adr") / contract]
    wraps = {}
    if scope == "netdb":
        contracts.extend((Path("docs/adr/0017-dns-forward.md"),
                          Path("docs/adr/0019-local-reverse-lookup.md"),
                          Path("docs/adr/0038-address-configuration.md"),
                          Path("docs/adr/0039-resolver-search.md"),
                          Path("docs/adr/0040-ipv6-scope.md"),
                          Path("docs/adr/0041-resolver-failover.md"),
                          Path("docs/adr/0042-resolver-options.md")))
        wraps = {directory / "files.c": ("fopen",),
                 directory / "scope_fault.c": ("ioctl", "__al_dns_config"),
                 directory / "lifetime.c": ("malloc", "calloc", "free")}
    if scope == "terminal":
        contracts.append(Path("docs/adr/0026-linux-terminal-controls.md"))
        wraps = {directory / "ioctl.c": ("__al_syscall",)}
    return execute_manifest_gate(
        f"phase10-{scope}", directory, public, wraps, assembly,
        partial(inputs, contracts), "OA_PHASE10_HOST", {"limits": [limits]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
