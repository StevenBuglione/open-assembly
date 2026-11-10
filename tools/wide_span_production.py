"""Prove the shipped wide-span member through unchanged independent public callers."""
import os
import math
from hashlib import sha256
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

from branch_coverage import verify_coverage
from failure_journal import hash_json
from gate import BUILD, EVIDENCE, GateError, checked, identify_tools, nm_symbols, verify_setup, write_evidence
from phase1 import NASM, RUNTIME_LINK, build_case, build_runtime
from phase4 import execute_probe
from phase6 import run_cases
from production import applicable_variants, source_paths
from runtime_manifest_gate import (PLANS, candidate_object, debug_candidate, execute_native, expected,
                                   load_plan_probes, read_manifest_json, timed_fuzz)
from spec import ROOT, regular_file, sha256_file
from stat_query_production import is_sha256, stat_runtime_artifacts

HELPER = '__al_wide_span'
SOURCE = Path('src/x86_64-linux/wchar/__al_wide_span.asm')
CALLERS = {'wcsspn': 1, 'wcscspn': 0}
CONTRACT = Path('docs/cookbook/wide-span-helper.md')


REQUIRED_CHECKS = {'generated_outputs', 'runtime_build', 'candidate_build', 'archive_member_identity',
                   'caller_domain', 'native_oracles', 'abi', 'branch_coverage', 'generated_stub',
                   'production_mutation', 'differential_fuzz'}
PUBLIC_WRAPPERS = frozenset({'wcsspn', 'wcscspn', 'wcspbrk'})


def span_dependency_bindings():
    path = EVIDENCE / f'{HELPER}.production.json'
    raw = regular_file(ROOT, path, 'wide span dependency').read_bytes()
    record = read_manifest_json(raw)
    inputs = span_inputs()
    if (type(record) is not dict or type(record.get('schema_version')) is not int
            or record['schema_version'] != 1 or record.get('scope') != 'production-private-dependency'
            or record.get('function') != HELPER or record.get('outcome') != 'pass' or record.get('inputs') != inputs):
        raise ValueError('no exact passing wide span dependency report')
    checks = record.get('checks')
    if (type(checks) is not dict or not REQUIRED_CHECKS <= checks.keys()
            or any(type(row) is not dict or row.get('outcome') != 'pass' for row in checks.values())):
        raise ValueError('incomplete wide span dependency checks')
    builds = checks['runtime_build'].get('artifacts')
    if (type(builds) is not dict or builds.keys() != {'first', 'second'}
            or builds['first'] != builds['second']):
        raise ValueError('wide span lacks equal complete repeated maps')
    artifacts = builds['first']
    if (type(artifacts) is not dict or artifacts.keys() != stat_runtime_artifacts(inputs)
            or not all(is_sha256(value) for value in artifacts.values())):
        raise ValueError('incomplete wide span runtime artifact map')
    candidate = checks['candidate_build']
    object_path = 'obj/wchar/__al_wide_span.o'
    if (candidate.get('source') != str(SOURCE) or candidate.get('source_sha256') != inputs[str(SOURCE)]
            or record.get('source_sha256') != inputs[str(SOURCE)]
            or candidate.get('object_sha256') != artifacts[object_path]):
        raise ValueError('wide span source or object binding differs')
    member = checks['archive_member_identity']
    if (member.get('member') != f'{HELPER}.o' or member.get('object_sha256') != artifacts[object_path]
            or member.get('archive_sha256') != artifacts['libopenasm.a']):
        raise ValueError('wide span actual archive member differs')
    callers = {name: {'mode': mode, 'source': f'src/x86_64-linux/wchar/{name}.asm',
                     'source_sha256': inputs[f'src/x86_64-linux/wchar/{name}.asm'],
                     'object_sha256': artifacts[f'obj/wchar/{name}.o']} for name, mode in CALLERS.items()}
    domain = checks['caller_domain']
    if (domain.get('callers') != callers or domain.get('modes') != [0, 1]
            or domain.get('importer_members') != sorted(f'{name}.o' for name in CALLERS)
            or domain.get('contract_sha256') != inputs[str(CONTRACT)]
            or domain.get('sha256') != hash_json(callers)
            or any(type(row.get('mode')) is not int for row in domain['callers'].values())):
        raise ValueError('wide span caller mode domain differs')
    abi_cases = {f'wide-matching-{name}-typed-abi' for name in CALLERS}
    observed_cases = {f'wide-matching-{name}-{suffix}' for name in CALLERS
                      for suffix in ('typed-abi', 'guard', 'fuzz')}
    if (type(checks['abi'].get('cases')) is not list
            or any(type(case) is not str for case in checks['abi']['cases'])
            or len(checks['abi']['cases']) != len(abi_cases)
            or set(checks['abi']['cases']) != abi_cases
            or type(checks['native_oracles'].get('cases')) is not dict
            or checks['native_oracles']['cases'].keys() != observed_cases
            or any(type(row) is not dict or row.get('outcome') != 'pass'
                   for row in checks['native_oracles']['cases'].values())):
        raise ValueError('wide span lacks both independent typed caller matrices')
    branch = checks['branch_coverage']
    if (type(branch.get('total')) is not int or branch['total'] < 1
            or branch.get('covered') != branch['total'] or type(branch.get('entry')) is not dict
            or branch['entry'].get('observed') is not True):
        raise ValueError('wide span lacks complete executed raw edges')
    mutation = checks['production_mutation']
    operators = mutation.get('operators')
    expected = {name: sha256(contents.encode()).hexdigest() for name, contents
                in applicable_variants(HELPER, SOURCE, {}, returns_value=True)}
    if (type(operators) is not list or any(type(row) is not dict or type(row.get('operator')) is not str for row in operators)
            or len(operators) != len(expected)
            or {row.get('operator') for row in operators} != expected.keys()
            or any(type(row.get('killed')) is not bool or row.get('source_sha256') != expected[row['operator']]
                   or not is_sha256(row.get('object_sha256')) for row in operators)
            or mutation.get('equivalent') != []):
        raise ValueError('wide span general raw mutation operators differ')
    killed, total = sum(row['killed'] for row in operators), len(operators)
    if (not total or killed * 100 < total * 90 or mutation.get('raw_total') != total
            or mutation.get('total') != total or mutation.get('raw_killed') != killed or mutation.get('killed') != killed):
        raise ValueError('wide span raw mutation threshold or denominator differs')
    for operator in operators:
        probes = operator.get('probes')
        if (type(probes) is not list or not probes or any(type(row) is not dict for row in probes)
                or any(row.get('returncode') not in (0, 11, 12, 13)
                or row.get('stdout_hex') != '' or row.get('stderr') != '' for row in probes)
                or (operator['killed'] and not any(row['returncode'] in (11, 12, 13) for row in probes))):
            raise ValueError('wide span mutation lacks an attributable named rejection')
    stub = checks['generated_stub']
    if (stub.get('expected_status') != 12 or type(stub.get('runs')) is not dict
            or stub['runs'].keys() != {'native', 'qemu'} or any(type(row) is not dict
                or row.get('returncode') != 12 or row.get('stdout_hex') != '' or row.get('stderr') != ''
                for row in stub['runs'].values())):
        raise ValueError('wide span lacks its automatic zero control')
    selectors = checks['differential_fuzz'].get('selectors')
    if type(selectors) is not dict or selectors.keys() != CALLERS.keys():
        raise ValueError('wide span lacks both packet selectors')
    for row in selectors.values():
        if type(row) is not dict:
            raise ValueError('malformed wide span packet selector')
        seconds, records, hashes = row.get('elapsed_s'), row.get('records'), row.get('sha256')
        if (row.get('outcome') != 'pass' or type(seconds) not in (int, float) or not math.isfinite(seconds)
                or seconds < 60 or type(records) is not int or records < 512 or records % 512
                or row.get('runs') != ['candidate', 'glibc', 'musl'] or type(hashes) is not dict
                or hashes.keys() != {'candidate', 'glibc', 'musl', 'input'}
                or not all(is_sha256(value) for value in hashes.values())
                or hashes['candidate'] != hashes['glibc'] or hashes['candidate'] != hashes['musl']):
            raise ValueError('wide span lacks timed independent packet agreement')
    return {'outcome': 'pass', 'engine': HELPER, 'functions': {HELPER: {
            'evidence': str(path), 'evidence_sha256': sha256(raw).hexdigest(), 'inputs_sha256': hash_json(inputs),
            'source_sha256': inputs[str(SOURCE)], 'object': object_path,
            'object_sha256': artifacts[object_path], 'archive_sha256': artifacts['libopenasm.a']}},
            'runtime_artifacts_sha256': hash_json(artifacts), 'callers_sha256': hash_json(callers)}


def check_span_archive(binding, artifacts):
    if (type(artifacts) is not dict or artifacts.keys() != stat_runtime_artifacts(span_inputs())
            or not all(is_sha256(value) for value in artifacts.values())
            or hash_json(artifacts) != binding['runtime_artifacts_sha256']):
        raise ValueError('wide span dependency runtime map differs')


def check_span_dependency_binding(checks):
    binding = span_dependency_bindings()
    if checks.get('dependency_closure') != binding:
        raise ValueError('wide span dependency evidence has changed')
    builds = checks.get('runtime_build', {}).get('artifacts')
    if (type(builds) is not dict or builds.keys() != {'first', 'second'} or builds['first'] != builds['second']):
        raise ValueError('span wrapper lacks equal complete runtime maps')
    check_span_archive(binding, builds['first'])
    candidate = checks.get('candidate_build', {})
    source = candidate.get('source')
    if type(source) is not str or source not in {f'src/x86_64-linux/wchar/{name}.asm' for name in PUBLIC_WRAPPERS}:
        raise ValueError('span wrapper source identity differs')
    object_path = 'obj/' + str(Path(source).relative_to('src/x86_64-linux').with_suffix('.o'))
    if (candidate.get('source_sha256') != span_inputs()[source]
            or candidate.get('object_sha256') != builds['first'][object_path]):
        raise ValueError('span wrapper object is outside its matching archive')
    return binding


def span_inputs():
    from production import phase2_inputs
    from spec import snapshot_inputs
    inputs = phase2_inputs()
    inputs.update(snapshot_inputs(ROOT, PLANS['wcsspn'].contracts))
    return dict(sorted(inputs.items()))


def object_text(path, directory, log):
    output = directory / (path.name + '.text.bin')
    checked(log, ['objcopy', '--dump-section', f'.text.{HELPER}={output}', path])
    return output.read_bytes()


def member_identity(runtime, original, record):
    command = ['ar', 'p', str(runtime[1]), f'{HELPER}.o']
    observed = subprocess.run(command, capture_output=True, check=True)
    if observed.stdout != original.read_bytes() or observed.stderr:
        raise GateError('shipped span archive member differs from its audited runtime object')
    record.update(outcome='pass', archive_sha256=sha256_file(runtime[1]), member=f'{HELPER}.o',
                  object_sha256=sha256_file(original), commands=[{'command': command,
                  'returncode': observed.returncode, 'stdout_sha256': sha256_file(original), 'stderr': ''}])


def caller_domain(runtime, inputs, record):
    referencing = {Path(path) for path in inputs if Path(path).suffix == '.asm'
                   and Path(path).parts[0] in {'src', 'apps', 'ext'} and Path(path) != SOURCE
                   and re.search(rf'\b{HELPER}\b', Path(path).read_text())}
    expected_sources = {Path(f'src/x86_64-linux/wchar/{name}.asm') for name in CALLERS}
    if referencing != expected_sources:
        raise GateError('wide span has a new shipped source reference requiring domain review')
    callers = {}
    for name, mode in CALLERS.items():
        path = Path(f'src/x86_64-linux/wchar/{name}.asm')
        body = path.read_text().split(f'{name}:\n', 1)[1].split('section .note.GNU-stack', 1)[0]
        instructions = [' '.join(line.strip().split()) for line in body.splitlines() if line.strip()]
        if instructions != [f'mov edx, {mode}', 'sub rsp, 8', f'call {HELPER}', 'add rsp, 8', 'ret']:
            raise GateError(f'{name}: reviewed span mode assignment changed')
        callers[name] = {'mode': mode, 'source': path.as_posix(), 'source_sha256': inputs[path.as_posix()],
                         'object_sha256': runtime[3][f'obj/wchar/{name}.o']}
    imported = checked(record['commands'], ['nm', '-A', '-u', runtime[1]])
    members = {line.rsplit(':', 1)[0].rsplit(':', 1)[1] for line in imported.splitlines()
               if re.search(rf':\s+U\s+{HELPER}$', line)}
    if members != {f'{name}.o' for name in CALLERS}:
        raise GateError('wide span archive importer domain differs from its two reviewed callers')
    record.update(outcome='pass', callers=callers, modes=[0, 1], importer_members=sorted(members),
                  contract=str(CONTRACT), contract_sha256=inputs[str(CONTRACT)], sha256=hash_json(callers))


def linked_helper(probe, obj, directory, runtime, log):
    directory.mkdir()
    _, artifacts = build_case(probe.case, directory / 'fixture', runtime, log)
    binary = directory / 'helper-candidate'
    objects = [directory / 'fixture' / f'test-{index}.o' for index in range(len(probe.case.sources))]
    checked(log, [*RUNTIME_LINK, f'--unique=.text.{HELPER}', '-o', binary, runtime[0], *objects, obj, runtime[1]])
    checked(log, ['tools/elf-audit', binary])
    defined = nm_symbols(log, binary, ['-g', '--defined-only'])
    if defined.get(HELPER) != 'T' or any(defined.get(name) != 'T' for name in probe.case.requires):
        raise GateError('public caller did not link the actual helper candidate definition')
    if object_text(binary, directory, log) != object_text(obj, directory, log):
        raise GateError('linked span instructions differ from the selected helper object')
    return binary, {**artifacts, 'helper-candidate': sha256_file(binary), 'helper_object_sha256': sha256_file(obj)}


def zero_stub(probe, directory, runtime, record):
    directory.mkdir()
    source = directory / f'{HELPER}.asm'
    obj = directory / f'{HELPER}.o'
    source.write_text(f'''bits 64
default rel
global {HELPER}:function
section .text.{HELPER} alloc exec nowrite progbits
{HELPER}:
    xor eax, eax
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
''')
    log = record['commands']
    checked(log, [*NASM, '-o', obj, source])
    checked(log, ['tools/elf-audit', '--assembly-object', obj])
    if nm_symbols(log, obj, ['-g', '--defined-only']) != {HELPER: 'T'}:
        raise GateError('generated span stub has the wrong export')
    binary, artifacts = linked_helper(probe, obj, directory / 'linked', runtime, log)
    execute_probe(probe, binary, directory / 'observed', record['runs'],
                  {'native': [], 'qemu': [shutil.which('qemu-x86_64')]}, (12, b'', b''))
    record.update(outcome='pass', expected_status=12, source_sha256=sha256_file(source), artifacts=artifacts)


def mutations(probes, source, original, directory, runtime, record):
    directory.mkdir()
    for operator, contents in applicable_variants(HELPER, source, record, returns_value=True):
        work = directory / operator
        work.mkdir()
        changed = work / f'{HELPER}.asm'
        changed.write_text(contents)
        item = {'operator': operator, 'source_sha256': sha256_file(changed), 'commands': [],
                'probes': [], 'killed': False}
        record['operators'].append(item)
        obj = candidate_object(work / f'{HELPER}.o', changed, HELPER, original, item['commands'])
        item['object_sha256'] = sha256_file(obj)
        for name in CALLERS:
            probe = probes[f'wide-matching-{name}-typed-abi']
            binary, artifacts = linked_helper(probe, obj, work / name, runtime, item['commands'])
            observed, log = execute_native(probe, binary, work / f'{name}-inputs')
            item['probes'].append({'case': probe.case.name, 'artifacts': artifacts, **log})
            if observed == expected(probe):
                continue
            if observed[0] not in (11, 12, 13) or observed[1:] != (b'', b''):
                raise GateError(f'{operator}: unclassified span mutation result {observed!r}')
            item['killed'] = True
            break
    count = len(record['operators'])
    killed = sum(item['killed'] for item in record['operators'])
    if not count or killed * 100 < count * 90:
        raise GateError(f'span mutation score below90 percent, {killed}/{count}')
    record.update(outcome='pass', raw_total=count, raw_killed=killed, total=count, killed=killed,
                  threshold_percent=90)
    print(f'PASS {HELPER} raw automatic mutations {killed}/{count}', flush=True)


def verify_span():
    evidence = {'schema_version': 1, 'scope': 'production-private-dependency', 'function': HELPER,
                'outcome': 'fail', 'checks': {}}
    checks = evidence['checks']
    try:
        evidence['toolchain'] = identify_tools('ar', 'make', 'objdump', 'qemu-x86_64', 'musl-gcc')
        evidence['inputs'] = verify_setup(checks, False, snapshot=span_inputs)
        inputs = evidence['inputs']
        evidence['source_sha256'] = inputs[str(SOURCE)]
        probes = {}
        for name in CALLERS:
            selected, _ = load_plan_probes(name, PLANS[name])
            probes.update({key: value for key, value in selected.items() if key.startswith('wide-matching-')})
        workspace = BUILD / 'production'
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix='wide-span-') as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            build = checks['runtime_build'] = {'outcome': 'fail', 'commands': []}
            runtime = build_runtime(directory / 'runtime', build['commands'])
            repeated = build_runtime(directory / 'repeated-runtime', build['commands'])
            if runtime[3] != repeated[3] or runtime[3].keys() != stat_runtime_artifacts(inputs):
                raise GateError('span runtime artifact maps are incomplete or differ')
            build.update(outcome='pass', artifacts={'first': runtime[3], 'second': repeated[3]})
            original = directory / 'runtime/obj/wchar' / f'{HELPER}.o'
            candidate = checks['candidate_build'] = {'outcome': 'fail', 'commands': []}
            checked(candidate['commands'], ['tools/lint', SOURCE])
            candidate.update(outcome='pass', source=str(SOURCE), source_sha256=sha256_file(SOURCE), object_sha256=sha256_file(original))
            member = checks['archive_member_identity'] = {'outcome': 'fail'}
            member_identity(runtime, original, member)
            domain = checks['caller_domain'] = {'outcome': 'fail', 'commands': []}
            caller_domain(runtime, inputs, domain)
            observations = checks['native_oracles'] = {'outcome': 'fail', 'cases': {}}
            target = directory / 'oracles'
            target.mkdir()
            runners = {'native': [], 'qemu': [shutil.which('qemu-x86_64')],
                       'valgrind': [shutil.which('valgrind'), '--quiet', '--error-exitcode=99',
                                    '--leak-check=full', '--errors-for-leak-kinds=all']}
            run_cases(probes.values(), target, runtime, repeated, runners, observations['cases'], 'OA_PHASE6_HOST')
            observations['outcome'] = 'pass'
            abi = checks['abi'] = {'outcome': 'fail', 'commands': [], 'cases': []}
            for name in CALLERS:
                case = f'wide-matching-{name}-typed-abi'
                obj = target / case / 'first/test-0.o'
                if nm_symbols(abi['commands'], obj, ['-g', '-u']).get('phase2_abi_probe_result') != 'U':
                    raise GateError('span caller ABI lacks its typed result trampoline')
                abi['cases'].append(case)
            abi['outcome'] = 'pass'
            trace = checks['branch_coverage'] = {'outcome': 'fail', 'commands': [], 'runs': []}
            work = directory / 'coverage'
            work.mkdir()
            debug = debug_candidate(HELPER, SOURCE, original, work, trace['commands'])
            probe = probes['wide-matching-wcsspn-guard']
            binary, artifacts = linked_helper(probe, debug, work / 'linked', runtime, trace['commands'])
            trace.update(debug_object_sha256=sha256_file(debug), linked_artifacts=artifacts)
            verify_coverage(trace, work, binary, HELPER, SOURCE,
                            [probes[f'wide-matching-{name}-guard'].case.args for name in CALLERS],
                            exact_case=probe.case, require_entry=True)
            stub = checks['generated_stub'] = {'outcome': 'fail', 'commands': [], 'runs': {}}
            zero_stub(probes['wide-matching-wcsspn-typed-abi'], directory / 'zero-stub', runtime, stub)
            mutation = checks['production_mutation'] = {'outcome': 'fail', 'operators': []}
            mutations(probes, SOURCE, original, directory / 'mutations', runtime, mutation)
            fuzz = checks['differential_fuzz'] = {'outcome': 'fail', 'selectors': {}}
            for name in CALLERS:
                row = fuzz['selectors'][name] = {'outcome': 'fail', 'commands': []}
                timed_fuzz(name, probes[f'wide-matching-{name}-fuzz'], PLANS[name], directory / name, runtime, row)
            fuzz['outcome'] = 'pass'
        if inputs != span_inputs():
            raise GateError('span proof inputs changed during verification')
        evidence['outcome'] = 'pass'
    except (GateError, KeyError, OSError, ValueError, subprocess.SubprocessError) as error:
        evidence['error'] = str(error)
        print(f'gate: {error}', file=sys.stderr)
    path = write_evidence(f'{HELPER}.production', evidence)
    print(f'private span proof evidence {path}', flush=True)
    return int(evidence['outcome'] != 'pass')


if __name__ == '__main__':
    os.chdir(ROOT)
    raise SystemExit(verify_span())
