"""Independent configuration and forward DNS search observations."""

from concurrent.futures import ThreadPoolExecutor
import socket
import subprocess

from oracle import A, AAAA, labels, pointer, reply, rr, unpack_query

CONFIGS = {
    "defaults": (b"nameserver invalid\n", "16 127.0.0.1 53 0 1\n"),
    "first-server": (b"nameserver nope\nnameserver 2001:DB8::a\nnameserver 192.0.2.11\n"
                     b"search a. b\noptions ndots:3\n", "28 2001:db8::a 53 2 3\na\nb\n"),
    "valid-six": (b"search . a..b c. d e f g h i j\noptions ndots:2 ndots:+7 ndots:bogus\n",
                  "16 127.0.0.1 53 6 2\nc\nd\ne\nf\ng\nh\n"),
    "last-directive": (b"search first.example second.example\ndomain final.example. unused\n"
                       b"options ndots:1 ndots:999\n", "16 127.0.0.1 53 1 15\nfinal.example\n"),
    "clear": (b"domain keep.example\nsearch . invalid..example\noptions ndots:0\n",
              "16 127.0.0.1 53 0 0\n"),
    "line-cap": (b"# comment\n" * 255 + b"search line256.example\nsearch line257.example\n",
                 "16 127.0.0.1 53 1 1\nline256.example\n"),
}

CONF = b"nameserver 127.0.0.1\nsearch dev.example prod.example\n"
MAX_NAME = ".".join(("a" * 63, "b" * 63, "c" * 63, "d" * 61))
V4 = bytes((192, 0, 2, 9))
V6 = bytes.fromhex("20010db8000000000000000000000009")


def candidate(name, kind, status="answer"):
    return name, kind, status


SCENARIOS = {
    "suffix-first": (CONF, "host", 2, 0, 0, 1, "host.prod.example",
                     (candidate("host.dev.example", A, "missing"), candidate("host.prod.example", A))),
    "absolute-first": (CONF, "api.v1", 2, 0, 0, 1, "api.v1.dev.example",
                       (candidate("api.v1", A, "missing"), candidate("api.v1.dev.example", A))),
    "zero-ndots": (CONF + b"options ndots:0\n", "host", 2, 0, 0, 1, "host", (candidate("host", A),)),
    "capped-ndots": (CONF + b"options ndots:100\n", "a.b.c", 2, 0, 0, 1, "a.b.c.dev.example",
                    (candidate("a.b.c.dev.example", A),)),
    "final-dot": (CONF, "api.v1.", 2, 0, socket.EAI_NONAME, 0, "-",
                  (candidate("api.v1", A, "missing"),)),
    "absolute-fallback": (CONF, "host", 2, 0, 0, 1, "host",
                          (candidate("host.dev.example", A, "missing"),
                           candidate("host.prod.example", A, "missing"), candidate("host", A))),
    "paired-families": (CONF, "host", 0, 0, 0, 3, "host.prod.example",
                        (candidate("host.dev.example", AAAA, "missing"), candidate("host.dev.example", A, "missing"),
                         candidate("host.prod.example", AAAA), candidate("host.prod.example", A))),
    "partial-family-answer": (CONF, "host", 0, 0, 0, 2, "host.dev.example",
                              (candidate("host.dev.example", AAAA), candidate("host.dev.example", A, "missing"))),
    "servfail-stops": (CONF, "host", 2, 0, socket.EAI_AGAIN, 0, "-",
                      (candidate("host.dev.example", A, "retry"),)),
    "long-skips-suffix": (CONF, MAX_NAME, 2, 0, 0, 1, MAX_NAME, (candidate(MAX_NAME, A),)),
    "local-file": (CONF, "fixture-local", 2, 0, 0, 1, "-", ()),
    "synthetic": (CONF, "localhost", 2, 0, 0, 1, "-", ()),
    "numeric": (CONF, "192.0.2.23", 2, 0, 0, 1, "-", ()),
    "numeric-only": (CONF, "host", 2, socket.AI_NUMERICHOST, socket.EAI_NONAME, 0, "-", ()),
}


def serve(peer, expected):
    observed = []
    for name, kind, status in expected:
        query, client = peer.recvfrom(2048)
        _, wire, qtype = unpack_query(query)
        if wire != labels(name.encode("ascii")) or qtype != kind:
            raise ValueError(f"unexpected DNS search query {wire!r}/{qtype}, expected {name}/{kind}")
        if status == "answer":
            record = rr(pointer(12), kind, V4 if kind == A else V6)
            peer.sendto(reply(query, (record,)), client)
        else:
            peer.sendto(reply(query, flags=0x8183 if status == "missing" else 0x8182), client)
        observed.append({"name": name, "type": kind, "response": status})
    return observed


def invoke(command, arguments, *, label):
    completed = subprocess.run([*command, *map(str, arguments)], env={"LC_ALL": "C"},
                               capture_output=True, timeout=10)
    if completed.returncode or completed.stderr:
        raise ValueError(f"resolver search {label} exited {completed.returncode}: {completed.stderr[:256]!r}")
    return completed.stdout.decode("ascii")


def run(command, workspace):
    config_results, cases = {}, {}
    workspace.mkdir()
    hosts = (workspace / "hosts").resolve()
    hosts.write_bytes(b"192.0.2.99 fixture-local\n")
    for label, (data, expected) in CONFIGS.items():
        config = (workspace / f"{label}.conf").resolve()
        config.write_bytes(data)
        actual = invoke(command, ["config", config], label=label)
        if actual != expected:
            raise ValueError(f"resolver config {label}: observed {actual!r}, expected {expected!r}")
        expected_server = " ".join(expected.splitlines()[0].split()[:3]) + "\n"
        server = invoke(command, ["server", config], label=label + "-server")
        if server != expected_server:
            raise ValueError(f"resolver config {label}: nameserver-only path differs")
        config_results[label] = {"config": actual, "nameserver_only": server}
    for label, (data, node, family, flags, status, kinds, canonical, expected) in SCENARIOS.items():
        config = (workspace / f"{label}.conf").resolve()
        config.write_bytes(data)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as peer:
            peer.bind(("127.0.0.1", 0))
            peer.settimeout(3)
            port = peer.getsockname()[1]
            with ThreadPoolExecutor(max_workers=1) as executor:
                task = executor.submit(serve, peer, expected)
                result = invoke(command, ("lookup", config, hosts, port, family, flags, status,
                                          1 if expected else -1, kinds, node, canonical), label=label)
                if result:
                    raise ValueError(f"resolver search {label} emitted output")
                cases[label] = task.result(timeout=4)
            peer.setblocking(False)
            try:
                peer.recvfrom(1)
            except BlockingIOError:
                continue
            raise ValueError(f"resolver search {label} issued an unplanned DNS query")
    return {"config": config_results, "queries": cases}
