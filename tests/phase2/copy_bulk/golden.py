import struct
MASK=(1<<64)-1
size=49152
seed=197
def fill(blank):
    out=bytearray()
    for i in range(size//4):
        bits=0x5a5a5a5a
        if not blank:
            x=(seed+i*0x9e3779b97f4a7c15)&MASK
            x^=x>>29
            x=x*0x94d049bb133111eb&MASK
            bits=(x^(x>>32))&0xffffffff
            if i&31<5: bits=[0,1,0xffffffff,0x80000000,0x7fffffff][i&31]
            if bits==0x5a5a5a5a: bits=0xa7b6c5d4
        out+=struct.pack('<I',bits)
    return out
def digest(p):
    v=0xcbf29ce484222325
    for b in p:v=(v^b)*0x100000001b3&MASK
    return v
lines=['schema = 1','stub = []','']
for name in ['memcpy','wmemcpy','memmove']:
    for mode in ['typed-abi','ordinary','guard','fuzz']:
        a=fill(False);b=fill(True)
        units=1;count=4 if name=='wmemcpy' else 1
        start=64+(seed&31);to=64+((seed>>5)&31)
        if name=='wmemcpy':start&=~3;to&=~3
        b[to:to+count]=a[start:start+count]
        packet=struct.pack('<QQ',2,seed).hex()
        golden=struct.pack('<8Q',0,count,units,start,to,0,digest(a),digest(b)).hex()
        source='abi.c' if mode=='typed-abi' else 'packets.c'
        sources=[f'tests/phase2/copy_bulk/{source}']
        if mode=='typed-abi':sources+=['tests/phase2/abi.asm']
        args=[name] if mode in ['typed-abi','fuzz'] else [name,mode]
        lines += ['[[case]]',f'name = "copy-bulk-{name}-{mode}"',f'sources = {sources!r}'.replace("'",'"'),f'requires = ["{name}"]',f'args = {args!r}'.replace("'",'"'),'env = {}','status = 0',f'stdin_hex = "{packet if mode=="fuzz" else ""}"','stdout = ""']
        if mode=='fuzz':lines += [f'stdout_hex = "{golden}"']
        lines += ['stderr = ""','oracle = ["reference:byte-ranges", "reference:wide-object-bounds", "abi:sysv-amd64"]']
        if mode=='typed-abi':
            lines += ['backends = ["native", "qemu"]','host_skip = "The shared typed trampoline checks candidate machine state and captured return bits."','[case.skip]','valgrind = "A no-op callback reports control-state mask 0x300 under Valgrind; native and QEMU report zero."']
        else:lines += ['backends = ["native", "qemu", "valgrind"]','host = true']
        lines+=['']
Path=None
open('tests/phase2/copy_bulk/manifest.toml','w').write('\n'.join(lines))
