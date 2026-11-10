"""Inspect the bounded ELF layout supported by Open Assembly's static PIE."""

from dataclasses import dataclass
import mmap
from struct import Struct

EHDR = Struct("<16sHHIQQQIHHHHHH")
PHDR = Struct("<IIQQQQQQ")
DYNAMIC = Struct("<qQ")
RELA = Struct("<QQq")

PAGE = 4096
MAX_IMAGE = (1 << 31) - 1
MAX_DYNAMIC = 4096
MAX_RELOCATIONS = 262144
PT_LOAD, PT_DYNAMIC, PT_INTERP, PT_TLS = 1, 2, 3, 7
PT_GNU_RELRO = 0x6474E552
PF_R, PF_RW, PF_RX = 4, 6, 5
ALLOWED_TAGS = {4, 5, 6, 7, 8, 9, 10, 11, 21, 30, 0x6FFFFEF5, 0x6FFFFFF9, 0x6FFFFFFB}


@dataclass(frozen=True)
class Segment:
    kind: int
    flags: int
    offset: int
    address: int
    filesz: int
    memsz: int
    align: int

    @classmethod
    def read(cls, image, offset):
        kind, flags, off, address, _, filesz, memsz, align = PHDR.unpack_from(image, offset)
        return cls(kind, flags, off, address, filesz, memsz, align)

    def has_file_bytes(self, address, size):
        return self.address <= address and address + size <= self.address + self.filesz

    def offset_at(self, address):
        return self.offset + address - self.address


def require(ok, message):
    if not ok:
        raise ValueError(message)


def unique(segments, kind, name):
    found = [segment for segment in segments if segment.kind == kind]
    require(len(found) == 1, f"expected one {name} segment")
    return found[0]


def inspect(image):
    require(len(image) >= EHDR.size, "truncated ELF header")
    ident, kind, machine, version, entry, phoff, _, _, ehsize, phsize, phnum, *_ = EHDR.unpack_from(image)
    require(ident[:7] == b"\x7fELF\x02\x01\x01" and (kind, machine, version) == (3, 62, 1),
            "expected a little-endian x86-64 static PIE")
    phend = phoff + phsize * phnum
    require((ehsize, phoff, phsize) == (EHDR.size, EHDR.size, PHDR.size) and
            1 <= phnum <= 64 and phend <= len(image), "unsupported program header table")
    segments = [Segment.read(image, offset) for offset in range(phoff, phend, phsize)]
    require(not any(segment.kind == PT_INTERP for segment in segments), "PIE interpreter present")
    loads = [segment for segment in segments if segment.kind == PT_LOAD]
    require(segments[0].kind == PT_LOAD and loads[0].address == loads[0].offset == 0 and
            loads[0].flags == PF_R and loads[0].filesz >= phend, "missing read-only ELF header load")
    previous_end = 0
    for segment in loads:
        require(segment.flags in {PF_R, PF_RW, PF_RX} and
                0 < segment.memsz and segment.filesz <= segment.memsz and
                segment.offset + segment.filesz <= len(image) and
                segment.address + segment.memsz <= MAX_IMAGE and
                previous_end <= (segment.address & -PAGE) and
                segment.align >= PAGE and (segment.align & (segment.align - 1)) == 0 and
                segment.address % segment.align == segment.offset % segment.align,
                "unsupported or overlapping PIE load segment")
        previous_end = (segment.address + segment.memsz + PAGE - 1) & -PAGE
    require(any(segment.flags == PF_RX and segment.has_file_bytes(entry, 1) for segment in loads),
            "PIE entry is outside executable file bytes")
    writable = [segment for segment in loads if segment.flags == PF_RW]
    require(len(writable) == 1, "expected one writable PIE load")
    writable = writable[0]
    tls_segments = [segment for segment in segments if segment.kind == PT_TLS]
    require(len(tls_segments) <= 1, "multiple PIE TLS templates")
    for tls in tls_segments:
        require(tls.flags == PF_R and tls.filesz <= tls.memsz <= MAX_IMAGE and
                tls.offset == writable.offset_at(tls.address) and
                writable.has_file_bytes(tls.address, tls.filesz) and
                (tls.align & (tls.align - 1)) == 0, "invalid PIE TLS template")
    dynamic = unique(segments, PT_DYNAMIC, "dynamic")
    relro = unique(segments, PT_GNU_RELRO, "GNU RELRO")
    require(dynamic.flags == PF_RW and 16 <= dynamic.filesz <= MAX_DYNAMIC and
            dynamic.memsz == dynamic.filesz and dynamic.filesz % DYNAMIC.size == 0 and
            dynamic.offset == writable.offset_at(dynamic.address) and
            writable.has_file_bytes(dynamic.address, dynamic.filesz), "unsupported PIE dynamic segment")
    require(relro.flags == PF_R and 0 < relro.filesz == relro.memsz and
            relro.offset == writable.offset_at(relro.address) and
            writable.has_file_bytes(relro.address, relro.filesz) and
            relro.has_file_bytes(dynamic.address, dynamic.filesz) and
            (relro.address + relro.memsz) % PAGE == 0, "unsupported PIE GNU RELRO extent")

    tags = {}
    ended = False
    for offset in range(dynamic.offset, dynamic.offset + dynamic.filesz, DYNAMIC.size):
        tag, value = DYNAMIC.unpack_from(image, offset)
        if tag == 0:
            require(value == 0, "invalid DT_NULL record")
            ended = True
            continue
        require(not ended and tag in ALLOWED_TAGS and tag not in tags,
                f"unsupported or repeated dynamic tag {tag:#x}")
        tags[tag] = value
    require(ended and tags.get(30) == 8 and tags.get(0x6FFFFFFB) == 0x08000001,
            "expected NOW and PIE dynamic flags")
    strings, symbols = tags.get(5, 0), tags.get(6, 0)
    first = loads[0]
    require(tags.get(10) == 1 and tags.get(11) == 24 and
            phend <= strings and first.has_file_bytes(strings, 1) and image[strings] == 0 and
            phend <= symbols and first.has_file_bytes(symbols, 24) and image[symbols:symbols + 24] == bytes(24),
            "unexpected PIE dynamic symbols or string table")
    if not ({7, 8, 9, 0x6FFFFFF9} & tags.keys()):
        return
    table, size = tags.get(7, 0), tags.get(8, 0)
    require(tags.get(9) == RELA.size and 0 < size <= RELA.size * MAX_RELOCATIONS and
            size % RELA.size == 0 and tags.get(0x6FFFFFF9, size // RELA.size) == size // RELA.size and
            phend <= table and table % 8 == 0 and first.has_file_bytes(table, size),
            "unsupported PIE RELA extent")
    previous = 0
    for offset in range(table, table + size, RELA.size):
        target, info, addend = RELA.unpack_from(image, offset)
        require(info == 8, "unsupported PIE relocation type or symbol index")
        require(previous < target and target % 8 == 0 and writable.has_file_bytes(target, 8) and
                (target + 8 <= dynamic.address or target >= dynamic.address + dynamic.memsz),
                "PIE relocation target is outside an allowed writable slot")
        require(any(segment.address <= addend <= segment.address + segment.memsz for segment in loads),
                "PIE relocation addend is outside the mapped image")
        previous = target


def audit_static_pie(path):
    try:
        with path.open("rb") as file, mmap.mmap(file.fileno(), 0, access=mmap.ACCESS_READ) as image:
            inspect(image)
    except ValueError as error:
        return str(error)
    return None
