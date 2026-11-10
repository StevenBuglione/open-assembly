"""Independent DNS nameserver and option observations from the published policy."""

from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack
from pathlib import Path
import select
import socket
import subprocess
from time import monotonic

import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "dns"))
from oracle import A, AAAA, PTR, labels, pointer, reply, rr, unpack_query

SERVERS = ("127.0.0.1", "::1", "127.0.0.2")
CONFIG = b"nameserver 127.0.0.1\nnameserver ::1\nnameserver 127.0.0.2\n"
TWO = b"nameserver 127.0.0.1\nnameserver ::1\n"
ADDRESSES = {A: bytes((192, 0, 2, 9)), AAAA: bytes.fromhex("20010db8000000000000000000000009"),
             PTR: labels(b"Reverse.Fixture")}
QUESTION = {A: b"node.test", AAAA: b"node.test", PTR: b"77.2.0.192.in-addr.arpa"}

# Every tuple names the destination server index, question type, and answer class.
# A negative server index encodes a cyclic offset from the first observed server.
FAILOVER = {
    "first-answer": (CONFIG, "forward", 2, 0, 1, ((0, A, "answer"),)),
    "third-after-errors": (CONFIG, "forward", 2, 0, 1,
                           ((0, A, "retry"), (1, A, "malformed"), (2, A, "answer"))),
    "nxdomain-terminal": (CONFIG, "forward", 2, socket.EAI_NONAME, 0, ((0, A, "missing"),)),
    "retry-priority": (CONFIG, "forward", 2, socket.EAI_AGAIN, 0,
                       ((0, A, "malformed"), (1, A, "retry"), (2, A, "malformed"))),
    "all-fatal": (CONFIG, "forward", 2, socket.EAI_FAIL, 0,
                  ((0, A, "malformed"), (1, A, "malformed"), (2, A, "malformed"))),
    "reverse-third": (CONFIG, "reverse", 2, 0, 0,
                      ((0, PTR, "retry"), (1, PTR, "malformed"), (2, PTR, "answer"))),
    "reverse-negative": (CONFIG, "reverse", 2, socket.EAI_NONAME, 0,
                         ((0, PTR, "retry"), (1, PTR, "missing"))),
}

OPTIONS = {
    "one-second-budget": (TWO + b"options timeout:1\n", "forward", 2, 0, 1,
                          ((0, A, "silent"), (1, A, "answer"))),
    "retry-same-order": (TWO + b"options attempts:2\n", "forward", 2, 0, 1,
                         ((0, A, "retry"), (1, A, "malformed"), (0, A, "answer"))),
    "second-round-negative": (TWO + b"options attempts:2\n", "forward", 2, socket.EAI_NONAME, 0,
                              ((0, A, "retry"), (1, A, "retry"), (0, A, "missing"))),
    "rotation-per-question": (TWO + b"options rotate\n", "forward", 0, 0, 3,
                              ((-1, AAAA, "answer"), (-2, A, "answer"))),
    "rotation-keeps-round-start": (TWO + b"options rotate attempts:2\n", "forward", 2, 0, 1,
                                   ((-1, A, "retry"), (-2, A, "retry"), (-1, A, "answer"))),
    "reverse-two-rounds": (TWO + b"options attempts:2\n", "reverse", 2, 0, 0,
                           ((0, PTR, "retry"), (1, PTR, "retry"), (0, PTR, "answer"))),
}

CONFIGS = {
    "failover": {
        "distinct-and-cap": (
            b"nameserver bad\nnameserver 127.0.0.1\nnameserver 127.0.0.1\nnameserver ::1\n"
            b"nameserver 0:0:0:0:0:0:0:1\nnameserver 127.0.0.2\nnameserver 127.0.0.3\n",
            "2 2 1 0\n16 127.0.0.1 53\n28 ::1 53\n16 127.0.0.2 53\n"),
        "fallback": (b"nameserver none\n", "0 2 1 0\n16 127.0.0.1 53\n"),
    },
    "options": {
        "lower-clamp": (TWO + b"options timeout:0 attempts:0 rotate\n",
                        "1 1 1 1\n16 127.0.0.1 53\n28 ::1 53\n"),
        "upper-clamp": (TWO + b"options timeout:999 attempts:999\n",
                        "1 30 5 0\n16 127.0.0.1 53\n28 ::1 53\n"),
        "last-valid": (TWO + b"options timeout:4 attempts:2\noptions timeout:0003 attempts:4 rotate\n"
                       b"options timeout:+7 attempts:3x timeout: attempts:\n",
                       "1 3 4 1\n16 127.0.0.1 53\n28 ::1 53\n"),
    },
}


def invoke(command, args, label):
    result = subprocess.run([*command, *map(str, args)], env={"LC_ALL": "C"},
                            capture_output=True, timeout=10)
    if result.returncode or result.stderr:
        raise ValueError(f"{label} probe exited {result.returncode}: {result.stderr[:256]!r}")
    return result.stdout.decode("ascii")


def serve(peers, plan):
    trace = []
    origin = None
    for expected, kind, behavior in plan:
        ready, _, _ = select.select(peers, [], [], 4)
        if len(ready) != 1:
            raise ValueError(f"expected one DNS query, observed {len(ready)} ready peers")
        peer = ready[0]
        actual = peers.index(peer)
        if expected < 0:
            if origin is None:
                origin = actual
            expected = (origin - expected - 1) % len(peers)
        query, client = peer.recvfrom(2048)
        _, name, qtype = unpack_query(query)
        if actual != expected or qtype != kind or name != labels(QUESTION[kind]):
            raise ValueError(f"expected server {expected}/{kind}, observed {actual}/{qtype}/{name!r}")
        if behavior in {"answer", "malformed"}:
            record = rr(pointer(12), kind, ADDRESSES[kind])
            peer.sendto(reply(query, (record if behavior == "answer" else record[:-1],)), client)
        elif behavior != "silent":
            peer.sendto(reply(query, flags=0x8183 if behavior == "missing" else 0x8182), client)
        trace.append({"server": actual, "type": kind, "behavior": behavior, "time": monotonic()})
    if trace:
        started = trace[0]["time"]
        for row in trace:
            row["seconds_since_first"] = round(row.pop("time") - started, 6)
    return trace


def sockets(stack, number):
    peers = []
    port = 0
    for address in SERVERS[:number]:
        family = socket.AF_INET6 if ":" in address else socket.AF_INET
        peer = stack.enter_context(socket.socket(family, socket.SOCK_DGRAM))
        if family == socket.AF_INET6:
            peer.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
        peer.bind((address, port))
        if not port:
            port = peer.getsockname()[1]
        peers.append(peer)
    return peers, port


def run(suite, command, work):
    work.mkdir()
    hosts = (work / "hosts").resolve()
    hosts.write_bytes(b"")
    configs, observations = {}, {}
    for name, (contents, expected) in CONFIGS[suite].items():
        config = (work / f"{name}.conf").resolve()
        config.write_bytes(contents)
        for mode in ("config", "config-reverse"):
            actual = invoke(command, (mode, config), f"{mode}-{name}")
            if actual != expected:
                raise ValueError(f"{mode} {name} yielded {actual!r}, expected {expected!r}")
        configs[name] = expected
    scenarios = FAILOVER if suite == "failover" else OPTIONS
    for name, (contents, mode, family, status, kinds, plan) in scenarios.items():
        config = (work / f"{name}.conf").resolve()
        config.write_bytes(contents)
        with ExitStack() as stack:
            peers, port = sockets(stack, contents.count(b"nameserver "))
            executor = stack.enter_context(ThreadPoolExecutor(max_workers=1))
            thread = executor.submit(serve, peers, plan)
            if invoke(command, (mode, config, hosts, port, family, status, kinds), name):
                raise ValueError(f"{name} emitted unexpected output")
            trace = thread.result(timeout=5)
            if select.select(peers, [], [], 0)[0]:
                raise ValueError(f"{name} sent an unplanned DNS query")
        if name == "one-second-budget" and not 0.8 <= trace[1]["seconds_since_first"] <= 1.8:
            raise ValueError("configured one-second timeout outside its measured bounds")
        observations[name] = trace
    if suite == "options":
        with ExitStack() as stack:
            peers, port = sockets(stack, 1)
            if invoke(command, ("invalid-budget", port), "invalid-budget") or select.select(peers, [], [], 0)[0]:
                raise ValueError("an invalid timeout budget used the network")
    return {"configurations": configs, "scenarios": observations}
