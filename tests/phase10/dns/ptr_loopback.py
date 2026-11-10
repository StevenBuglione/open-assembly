"""Independent reverse-DNS peer for the real public getnameinfo entry."""

from concurrent.futures import ThreadPoolExecutor
from ipaddress import ip_address
import socket
import struct
import subprocess

from loopback import receive_exact
from oracle import PTR, labels, pointer, reply, rr, unpack_query

HOST4 = "192.0.2.77"
HOST6 = "2001:db8::4d"
BYPASS = ("numeric", "local", "loopback", "unspecified")
MODES = ("v4", "v6", "mapped", "compatible", "tcp", "unrelated", "nxdomain",
         "fallback", "servfail", "malformed", "small", *BYPASS)
TARGET = b"\x05MiXeD\x07ExAmPlE\0"


def serve(udp, tcp, mode):
    packet, client = udp.recvfrom(1024)
    ident, name, kind = unpack_query(packet)
    reverse = ip_address(HOST6 if mode == "v6" else HOST4).reverse_pointer.encode("ascii")
    if kind != PTR or name != labels(reverse):
        raise ValueError(f"reverse DNS question differs for {mode}: {kind}, {name!r}")
    record = rr(pointer(12), PTR, TARGET)
    if mode == "tcp":
        udp.sendto(reply(packet, flags=0x8380), client)
        with tcp.accept()[0] as peer:
            peer.settimeout(5)
            size, = struct.unpack("!H", receive_exact(peer, 2))
            if not 12 <= size <= 512:
                raise ValueError(f"reverse DNS TCP request length {size}")
            forwarded = receive_exact(peer, size)
            if unpack_query(forwarded)[1:] != (name, PTR):
                raise ValueError("reverse DNS TCP retry changed the question")
            response = reply(forwarded, (record,))
            peer.sendall(struct.pack("!H", len(response)) + response)
        return {"udp_queries": 1, "tcp_queries": 1, "question": reverse.decode("ascii")}
    if mode == "unrelated":
        udp.sendto(reply(packet, (rr(pointer(12), PTR, labels(b"unrelated.example")),), ident=ident ^ 1), client)
    if mode in ("nxdomain", "fallback", "servfail"):
        response = reply(packet, flags=0x8182 if mode == "servfail" else 0x8183)
    else:
        response = reply(packet, (record[:-1] if mode == "malformed" else record,))
    udp.sendto(response, client)
    return {"udp_queries": 1, "tcp_queries": 0, "question": reverse.decode("ascii")}


def run_one(command, mode):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp, \
            socket.socket(socket.AF_INET, socket.SOCK_STREAM) as tcp:
        udp.bind(("127.0.0.1", 0))
        port = udp.getsockname()[1]
        tcp.bind(("127.0.0.1", port))
        tcp.listen()
        udp.settimeout(5)
        tcp.settimeout(5)
        with ThreadPoolExecutor(max_workers=1) as executor:
            peer = executor.submit(serve, udp, tcp, mode) if mode not in BYPASS else None
            result = subprocess.run([*command, str(port), mode], env={"LC_ALL": "C"},
                                    capture_output=True, timeout=9)
            if result.returncode or result.stdout or result.stderr:
                raise ValueError(f"public reverse lookup {mode} exited {result.returncode} "
                                 f"with {result.stdout!r} / {result.stderr!r}")
            if peer:
                return peer.result(timeout=6)
            udp.setblocking(False)
            try:
                udp.recvfrom(1)
            except BlockingIOError:
                return {"udp_queries": 0, "tcp_queries": 0}
            raise ValueError(f"public reverse lookup {mode} sent a bypassed query")


def run(command):
    return {mode: run_one(command, mode) for mode in MODES}
