"""Check immutable stable extension declarations and compile their layout assertions."""

from dataclasses import dataclass
from pathlib import Path
import re

from spec import (IDENTIFIER, boolean, fail, keys, matching, read_toml, regular_file,
                  sha256_file, split_parameters, string_list, version_one)


BASELINE_NAME = "extension-abi.toml"
TARGET = "x86_64-linux-sysv"
COMPILERS = ("gcc", "al-clang")
CTYPE = rf"{IDENTIFIER}(?: +{IDENTIFIER}| *\*)*"


@dataclass(frozen=True)
class Baseline:
    path: Path
    declarations: dict
    layouts: dict


def tokens(prototype):
    return re.findall(r"[A-Za-z_][A-Za-z0-9_]*|[0-9]+|[^\s]", prototype)


def declarations(package, rows, path):
    if type(rows) is not list or not rows:
        fail(path, "expected a nonempty [[function]] baseline")
    frozen = {}
    for row in rows:
        keys(row, {"name", "prototype", "narrow_args", "variadic", "noreturn"}, path)
        name = matching(row["name"], IDENTIFIER, path)
        if name in frozen or name not in package.functions:
            fail(path, f"duplicate or missing stable export {name}")
        split_parameters(row["prototype"], name, path)
        spec = package.functions[name]
        narrow = string_list(row["narrow_args"], r"[a-z0-9]+:[su](?:8|16|32)", path)
        actual = (tokens(spec.prototype), sorted(spec.abi.narrow_args), spec.abi.variadic, spec.abi.noreturn)
        expected = (tokens(row["prototype"]), sorted(narrow), boolean(row["variadic"], path),
                    boolean(row["noreturn"], path))
        if actual != expected:
            fail(path, f"stable declaration changed for {name}")
        frozen[name] = row["prototype"]
    if missing := package.functions.keys() - frozen.keys():
        fail(path, "stable export lacks a frozen declaration: " + ", ".join(sorted(missing)))
    return dict(sorted(frozen.items()))


def layouts(package, rows, path):
    if type(rows) is not list:
        fail(path, "expected an array of stable layouts")
    frozen = {}
    for row in rows:
        keys(row, {"name", "size", "align", "member"}, path)
        name = matching(row["name"], package.name + r"_[a-z][a-z0-9_]*", path)
        size, align, members = row["size"], row["align"], row["member"]
        if (name in frozen or type(size) is not int or type(align) is not int or
                not 1 <= align <= size < 2**31 or align & (align - 1) or size % align or
                type(members) is not list or not members):
            fail(path, f"invalid stable layout {name}")
        seen = set()
        for member in members:
            keys(member, {"name", "type", "offset"}, path, ("count",))
            field = matching(member["name"], IDENTIFIER, path)
            matching(member["type"], CTYPE, path)
            count, offset = member.get("count", 1), member["offset"]
            if (field in seen or type(count) is not int or not 1 <= count < 2**31 or
                    type(offset) is not int or not 0 <= offset < size):
                fail(path, f"invalid stable member {name}.{field}")
            seen.add(field)
        frozen[name] = row
    return frozen


def load_baselines(root, packages):
    baselines = {}
    for path in sorted((root / "tests/oracle").glob(f"*/{BASELINE_NAME}")):
        relative = path.relative_to(root)
        path = regular_file(root, relative, "stable extension ABI baseline")
        name = path.parent.name
        if name not in packages or packages[name].stability != "stable":
            fail(path, f"the frozen extension {name} must remain a stable package")
        data = read_toml(path)
        keys(data, {"schema_version", "target", "package", "function", "layout"}, path)
        version_one(data["schema_version"], path)
        if data["package"] != name or data["target"] != TARGET:
            fail(path, f"expected stable package {name} for {TARGET}")
        package = packages[name]
        baselines[name] = Baseline(relative, declarations(package, data["function"], path),
                                   layouts(package, data["layout"], path))
    if missing := sorted(name for name, package in packages.items()
                         if package.stability == "stable" and name not in baselines):
        fail("stable extension ABI", "missing protected baseline for " + ", ".join(missing))
    return baselines


def member_suffix(member):
    return f"[{member['count']}]" if "count" in member else ""


def header_layouts(baseline):
    lines = ["#include <stdint.h>", ""]
    for name, row in baseline.layouts.items():
        lines.append(f"struct {name} {{")
        lines.extend(f"    {field['type']} {field['name']}{member_suffix(field)};" for field in row["member"])
        lines.extend(("};", ""))
    return lines


def fixture(header, baseline):
    lines = [f'#include <{header}>', ""]
    for name, prototype in baseline.declarations.items():
        reference = f"__oa_frozen_{name}"
        lines.append(re.sub(rf"\b{re.escape(name)}(?= *\()", reference, prototype, count=1) + ";")
        lines.append(f"_Static_assert(__builtin_types_compatible_p(__typeof__(&{name}), "
                     f'__typeof__(&{reference})), "prototype {name}");')
    for name, row in baseline.layouts.items():
        ctype = f"struct {name}"
        lines.extend((f'_Static_assert(sizeof({ctype}) == {row["size"]}, "size {name}");',
                      f'_Static_assert(_Alignof({ctype}) == {row["align"]}, "alignment {name}");'))
        for member in row["member"]:
            field = member["name"]
            lines.extend((f'_Static_assert(offsetof({ctype}, {field}) == {member["offset"]}, "offset {name}.{field}");',
                          f"_Static_assert(__builtin_types_compatible_p(__typeof__((({ctype} *)0)->{field}), "
                          f'{member["type"]}{member_suffix(member)}), "type {name}.{field}");'))
    lines.extend(("", "int __oa_extension_abi_probe(void) { return 0; }", ""))
    return "\n".join(lines)


def verify_stable_abi(baselines, closure, directory, record):
    from gate import BUILD, COMPILE_FLAGS, checked

    packages = record["packages"] = {}
    for package in closure:
        baseline = baselines.get(package.name)
        if baseline is None:
            continue
        work = directory / f"stable-abi-{package.name}"
        work.mkdir()
        source = work / "abi.c"
        source.write_text(fixture(package.header, baseline), encoding="utf-8")
        headers = BUILD / "include/c"
        item = packages[package.name] = {
            "outcome": "fail", "target": TARGET, "baseline": str(baseline.path),
            "baseline_sha256": sha256_file(baseline.path), "fixture_sha256": sha256_file(source),
            "header": str(headers / package.header), "header_sha256": sha256_file(headers / package.header),
            "declarations": list(baseline.declarations), "layouts": baseline.layouts, "objects": {}, "commands": [],
        }
        for compiler in COMPILERS:
            obj = work / f"{compiler}.o"
            checked(item["commands"], [compiler, *COMPILE_FLAGS, "-I", headers, "-c", source, "-o", obj])
            checked(item["commands"], ["tools/elf-audit", "--test-object", obj])
            item["objects"][compiler] = sha256_file(obj)
        item["outcome"] = "pass"
    record["outcome"] = "pass"


def stable_abi_evidence(package, record, inputs):
    if type(record) is not dict or record.get("outcome") != "pass" or type(record.get("packages")) is not dict:
        return False
    item = record["packages"].get(package.name)
    if type(item) is not dict or item.get("outcome") != "pass" or item.get("target") != TARGET:
        return False
    baseline = f"tests/oracle/{package.name}/{BASELINE_NAME}"
    header = f"build/include/c/{package.header}"
    objects = item.get("objects")
    if (item.get("baseline") != baseline or item.get("baseline_sha256") != inputs.get(baseline) or
            item.get("header") != header or item.get("header_sha256") != inputs.get(header) or
            item.get("declarations") != sorted(package.functions) or type(objects) is not dict or
            objects.keys() != set(COMPILERS)):
        return False
    hashes = [item.get(key) for key in ("baseline_sha256", "header_sha256", "fixture_sha256")]
    return all(type(digest) is str and re.fullmatch(r"[a-f0-9]{64}", digest)
               for digest in (*hashes, *objects.values()))
