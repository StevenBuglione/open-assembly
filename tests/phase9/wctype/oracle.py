"""Read original Unicode 16 UCD text and emit independent wctype records."""

from hashlib import sha256
import gzip
from pathlib import Path
import struct

LIMIT = 0x110000
SPECIAL = (0x110000, 0x7fffffff, 0xfffffffe, 0xffffffff)
CLASSES = ("alnum", "alpha", "blank", "cntrl", "digit", "graph", "lower",
           "print", "punct", "space", "upper", "xdigit")
SYMBOLS = tuple("isw" + name for name in CLASSES) + (
    "towlower", "towupper", "wctype", "iswctype", "wctrans", "towctrans",
)
PACKET = struct.Struct("<IHHII")
FILES = {
    "DerivedCoreProperties.txt.gz": "1bb2bf27427f18113f57c30a4f74bca0bd022df642e8617ec7e9d07655d95b56",
    "PropList.txt.gz": "49ab7a5346753d804033299f2be003e9ede71502ea2e15d7e4026bb8ad6d2390",
    "UnicodeData.txt.gz": "daeb4dbe494e9b5be98d4ec4912680a6f1773eefbd4b44f1ab74a8160e567c7e",
}


def properties(text, names):
    data = {name: bytearray(LIMIT) for name in names}
    for line in text.splitlines():
        fields = line.partition("#")[0].strip().split(";")
        if len(fields) < 2 or (name := fields[1].strip()) not in data:
            continue
        parts = fields[0].strip().split("..")
        start, end = int(parts[0], 16), int(parts[-1], 16)
        if not 0 <= start <= end < LIMIT or any(data[name][start:end + 1]):
            raise ValueError(f"invalid or duplicate {name} interval")
        data[name][start:end + 1] = bytes([1]) * (end - start + 1)
    if any(not any(values) for values in data.values()):
        raise ValueError("missing UCD property")
    return data


def unicode_data(text):
    category = ["Cn"] * LIMIT
    lower, upper = {}, {}
    pending = None
    for line in text.splitlines():
        fields = line.split(";")
        if len(fields) != 15:
            raise ValueError("malformed UnicodeData row")
        cp = int(fields[0], 16)
        name, code = fields[1:3]
        if name.endswith(", First>"):
            if pending is not None:
                raise ValueError("nested UnicodeData range")
            pending = cp, name.removesuffix(", First>"), code
            continue
        if name.endswith(", Last>"):
            if pending is None or pending[1:] != (name.removesuffix(", Last>"), code):
                raise ValueError("unmatched UnicodeData range")
            first = pending[0]
            category[first:cp + 1] = [code] * (cp - first + 1)
            pending = None
            continue
        if pending is not None or category[cp] != "Cn":
            raise ValueError("unordered UnicodeData record")
        category[cp] = code
        if fields[12]:
            upper[cp] = int(fields[12], 16)
        if fields[13]:
            lower[cp] = int(fields[13], 16)
    if pending is not None:
        raise ValueError("unterminated UnicodeData range")
    return category, lower, upper


def load(directory):
    identities, data = {}, {}
    for name, expected in FILES.items():
        archive = (directory / name).read_bytes()
        if sha256(archive).hexdigest() != expected:
            raise ValueError(f"unpinned Unicode 16 data {name}")
        raw = gzip.decompress(archive)
        identities[name] = {"gzip_sha256": expected, "text_sha256": sha256(raw).hexdigest()}
        data[name] = raw.decode("utf-8")
    derived = data["DerivedCoreProperties.txt.gz"]
    spaces = data["PropList.txt.gz"]
    if not derived.startswith("# DerivedCoreProperties-16.0.0.txt\n") or not spaces.startswith(
            "# PropList-16.0.0.txt\n"):
        raise ValueError("unexpected Unicode property data version")
    return (identities, properties(derived, ("Alphabetic", "Lowercase", "Uppercase")),
            properties(spaces, ("White_Space",))["White_Space"],
            unicode_data(data["UnicodeData.txt.gz"]))


def pack(cp, flags, lower, upper):
    mask = sum(bool(value) << bit for bit, value in enumerate(flags))
    return PACKET.pack(cp, mask, 0, lower, upper)


def digits(cp):
    decimal = 0x30 <= cp <= 0x39
    return decimal, decimal or 0x41 <= cp <= 0x46 or 0x61 <= cp <= 0x66


def ascii_row(cp):
    upper = 0x41 <= cp <= 0x5a
    lower = 0x61 <= cp <= 0x7a
    alpha = upper or lower
    digit, xdigit = digits(cp)
    alnum = alpha or digit
    graph = 0x21 <= cp <= 0x7e
    flags = (alnum, alpha, cp in (0x09, 0x20), cp < 0x20 or cp == 0x7f, digit,
             graph, lower, 0x20 <= cp <= 0x7e, graph and not alnum,
             cp == 0x20 or 0x09 <= cp <= 0x0d, upper, xdigit)
    return pack(cp, flags, cp + 32 if upper else cp, cp - 32 if lower else cp)


def unicode_row(cp, derived, space, category, lower_map, upper_map):
    upper, lower = derived["Uppercase"], derived["Lowercase"]
    alpha = bool(derived["Alphabetic"][cp] or upper[cp] or lower[cp])
    digit, xdigit = digits(cp)
    alnum = alpha or digit
    code = category[cp]
    printable = code[0] in "LMNPS" or code in ("Zs", "Co")
    graph = printable and not space[cp]
    punct = graph and not alnum and code[0] in "PS"
    flags = (alnum, alpha, cp == 9 or code == "Zs", code == "Cc", digit, graph,
             lower[cp], printable, punct, space[cp], upper[cp], xdigit)
    low = lower_map.get(cp, cp) if upper[cp] else cp
    high = upper_map.get(cp, cp) if lower[cp] else cp
    return pack(cp, flags, low if lower[low] else cp, high if upper[high] else cp)


def make_records(source, output):
    identities, derived, space, (category, lower, upper) = load(source)
    invalid = (0x80, 0xa0, 0x391, 0xd800, 0x10ffff, *SPECIAL)
    domains = {"ascii": list(range(128)) + [SPECIAL[-1]], "c": list(range(128)) + list(invalid),
               "unicode": range(LIMIT), "invalid": SPECIAL}
    counts = {}
    for name, domain in domains.items():
        path = output / f"{name}.packets"
        with path.open("wb") as target:
            for cp in domain:
                if name == "unicode":
                    row = unicode_row(cp, derived, space, category, lower, upper)
                else:
                    row = ascii_row(cp)
                target.write(row)
        count = len(domain)
        counts[name] = {"rows": count, "sha256": sha256(path.read_bytes()).hexdigest()}
    return identities, counts
