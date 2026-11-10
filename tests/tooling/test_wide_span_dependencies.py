"""Seed private span report/domain failures without building candidate code."""
from copy import deepcopy
from hashlib import sha256
from pathlib import Path
import json
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from failure_journal import hash_json
from gate import GateError
from production import applicable_variants
import wide_span_production as span


class SpanDependencies(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.path=Path(self.temporary.name)/'report.json'
        self.inputs={str(path.relative_to(ROOT)):span.sha256_file(path) for prefix in ('src','apps','ext')
                     for path in (ROOT/prefix).rglob('*.asm')}
        self.inputs[str(span.CONTRACT)]=span.sha256_file(ROOT/span.CONTRACT)
        self.inputs['tools/queue']=span.sha256_file(ROOT/'tools/queue')
        snapshot=patch.object(span,'span_inputs',return_value=deepcopy(self.inputs))
        snapshot.start();self.addCleanup(snapshot.stop)
        self.artifacts={name:sha256(name.encode()).hexdigest() for name in span.stat_runtime_artifacts(self.inputs)}
        checks={name:{'outcome':'pass'} for name in span.REQUIRED_CHECKS}
        checks['runtime_build']['artifacts']={'first':dict(self.artifacts),'second':dict(self.artifacts)}
        checks['candidate_build'].update(source=str(span.SOURCE),source_sha256=self.inputs[str(span.SOURCE)],
                                        object_sha256=self.artifacts['obj/wchar/__al_wide_span.o'])
        checks['archive_member_identity'].update(member='__al_wide_span.o',
            object_sha256=self.artifacts['obj/wchar/__al_wide_span.o'],archive_sha256=self.artifacts['libopenasm.a'])
        callers={name:{'mode':mode,'source':f'src/x86_64-linux/wchar/{name}.asm',
                    'source_sha256':self.inputs[f'src/x86_64-linux/wchar/{name}.asm'],
                    'object_sha256':self.artifacts[f'obj/wchar/{name}.o']} for name,mode in span.CALLERS.items()}
        checks['caller_domain'].update(callers=callers,modes=[0,1],importer_members=sorted(f'{n}.o' for n in span.CALLERS),
                                       contract_sha256=self.inputs[str(span.CONTRACT)],sha256=hash_json(callers))
        checks['abi']['cases']=[f'wide-matching-{n}-typed-abi' for n in span.CALLERS]
        checks['native_oracles']['cases']={f'wide-matching-{n}-{suffix}':{'outcome':'pass'}
            for n in span.CALLERS for suffix in ('typed-abi','guard','fuzz')}
        checks['branch_coverage'].update(total=10,covered=10,entry={'observed':True})
        operators=[{'operator':name,'source_sha256':sha256(text.encode()).hexdigest(),'object_sha256':'a'*64,
                    'killed':True,'probes':[{'returncode':12,'stdout_hex':'','stderr':''}]}
            for name,text in applicable_variants(span.HELPER,span.SOURCE,{},returns_value=True)]
        checks['production_mutation'].update(operators=operators,equivalent=[],total=len(operators),
            raw_total=len(operators),killed=len(operators),raw_killed=len(operators))
        checks['generated_stub'].update(expected_status=12,runs={n:{'returncode':12,'stdout_hex':'','stderr':''} for n in ('native','qemu')})
        checks['differential_fuzz']['selectors']={n:{'outcome':'pass','elapsed_s':60,'records':512,
            'runs':['candidate','glibc','musl'],'sha256':{k:'b'*64 for k in ('candidate','glibc','musl','input')}} for n in span.CALLERS}
        self.record={'schema_version':1,'scope':'production-private-dependency','function':span.HELPER,'outcome':'pass',
                     'inputs':self.inputs,'source_sha256':self.inputs[str(span.SOURCE)],'checks':checks}
        self.patcher=patch.object(span,'regular_file',return_value=self.path)
        self.patcher.start();self.addCleanup(self.patcher.stop)

    def save(self):
        self.path.write_text(json.dumps(self.record))

    def test_valid_and_wrapper_binding(self):
        self.save();binding=span.span_dependency_bindings()
        checks={'dependency_closure':binding,'runtime_build':{'artifacts':{'first':dict(self.artifacts),'second':dict(self.artifacts)}},
                'candidate_build':{'source':'src/x86_64-linux/wchar/wcsspn.asm',
                'source_sha256':self.inputs['src/x86_64-linux/wchar/wcsspn.asm'],
                'object_sha256':self.artifacts['obj/wchar/wcsspn.o']}}
        self.assertEqual(span.check_span_dependency_binding(checks),binding)
        checks['runtime_build']['artifacts']['second']['obj/wchar/wcsspn.o']='0'*64
        with self.assertRaisesRegex(ValueError,'equal complete'):
            span.check_span_dependency_binding(checks)
        with self.assertRaisesRegex(ValueError,'runtime map differs'):
            span.check_span_archive(binding,{**self.artifacts,'obj/wchar/wcsspn.o':'0'*64})

    def test_absent(self):
        with self.assertRaises(OSError): span.span_dependency_bindings()

    def test_stale(self):
        self.record['inputs']['tools/queue']='0'*64;self.save()
        with self.assertRaisesRegex(ValueError,'exact passing'): span.span_dependency_bindings()

    def test_wrong_second_map(self):
        self.record['checks']['runtime_build']['artifacts']['second']['obj/wchar/wcsspn.o']='0'*64;self.save()
        with self.assertRaisesRegex(ValueError,'repeated maps'): span.span_dependency_bindings()

    def test_wrong_member(self):
        self.record['checks']['archive_member_identity']['object_sha256']='0'*64;self.save()
        with self.assertRaisesRegex(ValueError,'actual archive member'): span.span_dependency_bindings()

    def test_wrong_archive(self):
        self.record['checks']['archive_member_identity']['archive_sha256']='0'*64;self.save()
        with self.assertRaisesRegex(ValueError,'actual archive member'): span.span_dependency_bindings()

    def test_duplicate_and_nonfinite(self):
        self.save();original=self.path.read_text()
        for addition in (',"function":"__al_wide_span"',',"extra":NaN',',"extra":1e999'):
            self.path.write_text(original[:-1]+addition+'}')
            with self.assertRaises(ValueError): span.span_dependency_bindings()

    def test_unhashable_case_and_operator_rejected(self):
        original=deepcopy(self.record)
        for field in ('abi-case','operator'):
            self.record=deepcopy(original)
            if field=='abi-case': self.record['checks']['abi']['cases']=[{},{}]
            else: self.record['checks']['production_mutation']['operators'][0]['operator']={}
            self.save()
            with self.subTest(field=field),self.assertRaises(ValueError):
                span.span_dependency_bindings()

    def test_fault_is_not_a_kill(self):
        self.record['checks']['production_mutation']['operators'][0]['probes'][0]['returncode']=-11;self.save()
        with self.assertRaisesRegex(ValueError,'attributable'): span.span_dependency_bindings()

    def test_new_app_and_extension_callers(self):
        read=Path.read_text
        for source in ('apps/new.asm','ext/new/src/new.asm'):
            inputs={**self.inputs,source:'a'*64}
            def text(path,*args,**kwargs):
                return 'extern __al_wide_span:function\n' if str(path)==source else read(path,*args,**kwargs)
            with patch.object(Path,'read_text',text):
                with self.assertRaisesRegex(GateError,'new shipped source reference'):
                    span.caller_domain(None,inputs,{'commands':[]})

    def test_changed_literal_mode(self):
        read=Path.read_text
        def text(path,*args,**kwargs):
            value=read(path,*args,**kwargs)
            return value.replace('mov edx, 1','mov edx, 0') if str(path)=='src/x86_64-linux/wchar/wcsspn.asm' else value
        with patch.object(Path,'read_text',text):
            with self.assertRaisesRegex(GateError,'mode assignment changed'):
                span.caller_domain(None,self.inputs,{'commands':[]})


if __name__=='__main__':
    unittest.main()
