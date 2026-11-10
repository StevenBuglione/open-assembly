"""Independent UDP and TCP DNS loopback peer."""

from concurrent.futures import ThreadPoolExecutor
import socket
import struct
import subprocess
import time

from oracle import A, AAAA, RESULT, answer, labels, pointer, reply, rr, unpack_query

NAME = labels(b"query.example")
ADDRESS4 = bytes.fromhex("c000024d")
ADDRESS6 = bytes.fromhex("20010db800000000000000000000004d")


def receive_exact(peer, count):
    result = bytearray()
    while len(result) < count:
        fragment = peer.recv(count - len(result))
        if not fragment:
            raise ValueError("DNS TCP query ended before its frame")
        result.extend(fragment)
    return bytes(result)


def serve(udp, tcp, mode, qtype):
    packet, client = udp.recvfrom(2048)
    ident, name, kind = unpack_query(packet)
    if name != NAME or kind != qtype:
        raise ValueError("loopback DNS peer observed a different question")
    correct = ADDRESS4 if qtype == A else ADDRESS6
    record = rr(pointer(12), qtype, correct)
    if mode == "silent":
        return {"udp_queries": 1, "tcp_queries": 0}
    if mode == "wrong-only":
        udp.sendto(reply(packet, (record,), ident=ident ^ 1), client)
        return {"udp_queries": 1, "tcp_queries": 0}
    if mode == "nxdomain":
        udp.sendto(reply(packet, flags=0x8183), client)
        return {"udp_queries": 1, "tcp_queries": 0}
    if mode == "malformed":
        udp.sendto(reply(packet, (record[:-1],)), client)
        return {"udp_queries": 1, "tcp_queries": 0}
    if mode == "spoof":
        wrong = bytes([0x77]) * len(correct)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as foreign:
            foreign.bind(("127.0.0.1", 0))
            foreign.sendto(reply(packet, (rr(pointer(12), qtype, wrong),)), client)
        udp.sendto(reply(packet, (rr(pointer(12), qtype, wrong),), ident=ident ^ 1), client)
    if mode in {"tcp", "tcp-mismatch"}:
        udp.sendto(reply(packet, flags=0x8380), client)
        with tcp.accept()[0] as peer:
            peer.settimeout(5)
            size = struct.unpack("!H", receive_exact(peer, 2))[0]
            if not 1 <= size <= 512:
                raise ValueError("invalid client DNS TCP query length")
            forwarded = receive_exact(peer, size)
            tcp_id, tcp_name, tcp_kind = unpack_query(forwarded)
            if tcp_name != name or tcp_kind != kind:
                raise ValueError("DNS TCP retry changed the question")
            response = reply(forwarded, (record,), ident=tcp_id ^ 1 if mode == "tcp-mismatch" else tcp_id)
            length = struct.pack("!H", len(response))
            peer.sendall(length[:1])
            time.sleep(0.02)
            peer.sendall(length[1:] + response[:9])
            time.sleep(0.02)
            peer.sendall(response[9:])
        return {"udp_queries": 1, "tcp_queries": 1}
    udp.sendto(reply(packet, (record,)), client)
    return {"udp_queries": 1, "tcp_queries": 0}


def run_one(command, mode, qtype, expected):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp,             socket.socket(socket.AF_INET, socket.SOCK_STREAM) as tcp:
        udp.bind(("127.0.0.1", 0))
        port = udp.getsockname()[1]
        tcp.bind(("127.0.0.1", port))
        tcp.listen()
        udp.settimeout(5)
        tcp.settimeout(5)
        with ThreadPoolExecutor(max_workers=1) as peer:
            server = peer.submit(serve, udp, tcp, mode, qtype)
            cmd = [*command, str(port), "A" if qtype == A else "AAAA"]
            started = time.monotonic()
            result = subprocess.run(cmd, env={"LC_ALL": "C"}, capture_output=True, timeout=10)
            elapsed = time.monotonic() - started
            exchange = server.result(timeout=6)
    if result.returncode or result.stderr:
        raise ValueError(f"DNS {mode} probe exited {result.returncode} with {result.stderr!r}")
    address = ADDRESS4 if qtype == A else ADDRESS6
    data = answer(qtype, NAME, (address,)) if not expected else b""
    if result.stdout != RESULT.pack(expected, len(data)) + data:
        raise ValueError(f"DNS {mode} response differs: {result.stdout.hex()}")
    if mode in {"silent", "wrong-only"} and not 1.8 <= elapsed <= 7:
        raise ValueError(f"DNS {mode} timeout outside the measured window: {elapsed:.3f}s")
    return {**exchange, "status": expected, "elapsed_s": round(elapsed, 6),
            "output_hex": result.stdout.hex()}


def run(command):
    return {mode: run_one(command, mode, qtype, status) for mode, qtype, status in (
        ("udp", A, 0), ("spoof", A, 0), ("tcp", AAAA, 0),
        ("tcp-mismatch", A, socket.EAI_FAIL), ("malformed", A, socket.EAI_FAIL),
        ("nxdomain", AAAA, socket.EAI_NONAME), ("silent", A, socket.EAI_AGAIN),
        ("wrong-only", A, socket.EAI_AGAIN),
    )}
