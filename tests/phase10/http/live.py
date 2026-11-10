"""Check the frozen server through actual IPv4 loopback connections."""

from contextlib import ExitStack
import os
import re
import select
import socket
import struct
import subprocess
import time

from oracle import HEAD, request

ENVIRONMENT = {"LC_ALL": "C"}
BODY = b"open-assembly\n"


def readiness(server, timeout):
    deadline = time.monotonic() + timeout
    line = b""
    while b"\n" not in line:
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not select.select([server.stdout], [], [], remaining)[0]:
            raise ValueError("HTTP server readiness timeout")
        part = os.read(server.stdout.fileno(), 80)
        if not part:
            raise ValueError(f"HTTP server terminated before readiness ({server.poll()})")
        line += part
        if len(line) > 32:
            raise ValueError(f"invalid readiness line {line!r}")
    match = re.fullmatch(rb"PORT ([0-9]{1,5})\n", line)
    if not match or not 0 < int(match[1]) <= 65535:
        raise ValueError(f"invalid readiness line {line!r}")
    return int(match[1])


def exchange(port, data, *, eof=False, timeout=5):
    with socket.create_connection(("127.0.0.1", port), timeout=timeout) as peer:
        peer.sendall(data)
        if eof:
            peer.shutdown(socket.SHUT_WR)
        return received(peer)


def received(peer):
    response = bytearray()
    while len(response) <= 4096:
        data = peer.recv(1024)
        if not data:
            return bytes(response)
        response.extend(data)
    raise ValueError("HTTP response exceeded the fixture limit")


def check(data, result):
    status, head = result & 0xffff, result & HEAD
    raw_headers, separator, payload = data.partition(b"\r\n\r\n")
    line, *fields = raw_headers.split(b"\r\n")
    if not separator or not re.fullmatch(rb"HTTP/1\.1 " + str(status).encode() + rb" [\x20-\x7e]+", line):
        raise ValueError(f"expected HTTP/1.1 {status}, received {data[:256]!r}")
    headers = {}
    for field in fields:
        name, delimiter, value = field.partition(b":")
        name = name.lower()
        if not delimiter or not name or name in headers:
            raise ValueError(f"invalid response field {field!r}")
        headers[name] = value.strip(b" \t")
    length = len(BODY) if status == 200 else 0
    expected = BODY if status == 200 and not head else b""
    if (headers.get(b"connection", b"").lower() != b"close"
            or headers.get(b"content-length") != str(length).encode() or payload != expected):
        raise ValueError(f"response framing mismatch for {result}: {data[:256]!r}")
    if status == 200 and headers.get(b"content-type") != b"text/plain":
        raise ValueError(f"unexpected content type {headers.get(b'content-type')!r}")
    if status == 405 and headers.get(b"allow") != b"GET, HEAD":
        raise ValueError(f"unexpected Allow header {headers.get(b'allow')!r}")


def startup(command):
    result = {}
    for args, expected in ((("-",), 2), (("65536",), 2), (("1x",), 2), (("1", "2"), 2)):
        observation = subprocess.run([*command, *args], capture_output=True, timeout=10, env=ENVIRONMENT)
        if observation.returncode != expected or observation.stdout:
            raise ValueError(f"invalid HTTP invocation {args!r}: {observation!r}")
        result[" ".join(args)] = {"status": observation.returncode, "stderr_hex": observation.stderr.hex()}
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as occupied:
        occupied.bind(("127.0.0.1", 0))
        occupied.listen()
        port = occupied.getsockname()[1]
        observation = subprocess.run([*command, str(port)], capture_output=True,
                                     timeout=10, env=ENVIRONMENT)
        if observation.returncode != 1 or observation.stdout:
            raise ValueError(f"occupied port did not fail startup: {observation!r}")
        result["occupied"] = {"status": observation.returncode, "stderr_hex": observation.stderr.hex()}
    return result


def capacity(port):
    partial = b"GET / HTTP/1.1\r\nHost: "
    with ExitStack() as resources:
        clients = [resources.enter_context(socket.create_connection(("127.0.0.1", port), timeout=5))
                   for _ in range(64)]
        for peer in clients:
            peer.sendall(partial)
        # Every preceding connect has completed on the single accept queue.
        extra = resources.enter_context(socket.create_connection(("127.0.0.1", port), timeout=5))
        try:
            if extra.recv(1) != b"":
                raise ValueError("capacity connection unexpectedly replied")
        except ConnectionResetError:
            pass
        for peer in reversed(clients):
            peer.sendall(b"local\r\n\r\n")
        for peer in clients:
            check(received(peer), 200)
    return len(clients)


def server_cases(command, *, ready_timeout=15, peer_timeout=5):
    server = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=ENVIRONMENT)
    observations = {}
    try:
        port = readiness(server, ready_timeout)
        vectors = [
            ("get", request(), 200), ("head", request(b"HEAD"), HEAD | 200),
            ("missing", request(b"GET", b"/missing"), 404),
            ("head-missing", request(b"HEAD", b"/missing"), HEAD | 404),
            ("method", request(b"PATCH"), 405), ("missing-host", request(fields=()), 400),
            ("http10", request(version=b"1.0", fields=()), 200),
            ("oversize", b"x" * 8192, 431),
            ("pipeline-ignored", request() + request(b"HEAD"), 200),
        ]
        for name, data, result in vectors:
            check(exchange(port, data, eof=name == "get", timeout=peer_timeout), result)
            observations[name] = result & 0xffff
        if exchange(port, b"GET / HTTP/1.1\r\n", eof=True):
            raise ValueError("partial input at EOF unexpectedly replied")
        observations["partial-eof"] = True

        with socket.create_connection(("127.0.0.1", port), timeout=5) as peer:
            peer.sendall(b"GET / HTTP/1.1\r\nHost: local\r\n\r")
            if select.select([peer], [], [], 0.05)[0]:
                raise ValueError("incomplete terminator unexpectedly replied")
            peer.sendall(b"\n")
            check(received(peer), 200)
        observations["fragmented"] = True
        observations["capacity-served"] = capacity(port)

        with socket.create_connection(("127.0.0.1", port), timeout=5) as reset:
            reset.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
            reset.sendall(request())
        check(exchange(port, request()), 200)
        observations["peer-reset-survival"] = True

        with socket.create_connection(("127.0.0.1", port), timeout=10) as idle:
            idle.sendall(b"G")
            start = time.monotonic()
            if idle.recv(1):
                raise ValueError("idle connection unexpectedly replied")
            elapsed = time.monotonic() - start
            if not 4.5 <= elapsed <= 10:
                raise ValueError(f"idle close outside measured window: {elapsed:.3f}s")
        observations["idle-close-seconds"] = round(elapsed, 6)
        check(exchange(port, request()), 200)
        observations["post-idle-service"] = True
        if server.poll() is not None:
            raise ValueError(f"HTTP server stopped before supervisor signal: {server.returncode}")
    finally:
        server.terminate()
        try:
            stdout, stderr = server.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()
            server.communicate()
            raise ValueError("HTTP server did not stop after SIGTERM") from None
    if server.returncode != -15 or stdout or stderr:
        raise ValueError(f"HTTP server exit={server.returncode}, extra stdout={stdout!r}, stderr={stderr!r}")
    observations["supervisor-exit"] = server.returncode
    return observations


def timeout_controls(python):
    try:
        server_cases([python, "-c", "import time; time.sleep(30)"], ready_timeout=0.25)
    except ValueError as error:
        if str(error) != "HTTP server readiness timeout":
            raise
    else:
        raise ValueError("readiness hang control escaped the deadline")

    stalled = ("import socket,time; s=socket.socket(); s.bind(('127.0.0.1',0)); s.listen(); "
               "print('PORT',s.getsockname()[1],flush=True); c,_=s.accept(); time.sleep(30)")
    try:
        server_cases([python, "-c", stalled], ready_timeout=5, peer_timeout=0.25)
    except TimeoutError:
        pass
    else:
        raise ValueError("post-readiness hang control escaped the deadline")
    return {"readiness_hang": "rejected", "response_hang": "rejected"}
