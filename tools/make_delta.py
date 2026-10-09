"""CTPDIFF1: a raw-DEFLATE stream of source-copy and literal instructions.

No third-party runtime dependency. The Windows installer implements the same
decoder using .NET. SHA-256 checks belong to the accompanying manifest.
"""
from pathlib import Path
import argparse,hashlib,struct,zlib
MAGIC=b'CTPDIFF1'
BLOCK=64

def create_delta(source: bytes, target: bytes) -> bytes:
    index={}
    for offset in range(0,len(source)-BLOCK+1,BLOCK):
        block=source[offset:offset+BLOCK]
        index.setdefault(block,offset)
    body=bytearray(struct.pack('<Q',len(target)))
    pos=literal_start=0
    while pos+BLOCK<=len(target):
        offset=index.get(target[pos:pos+BLOCK])
        if offset is None:
            pos+=1
            continue
        length=BLOCK
        for step in (16384,1024,64,1):
            while (offset+length+step<=len(source) and pos+length+step<=len(target)
                   and source[offset+length:offset+length+step]==target[pos+length:pos+length+step]):
                length+=step
        if pos>literal_start:
            body.extend(b'\x01'+struct.pack('<I',pos-literal_start)+target[literal_start:pos])
        body.extend(b'\x00'+struct.pack('<QI',offset,length))
        pos+=length
        literal_start=pos
    if literal_start<len(target):
        body.extend(b'\x01'+struct.pack('<I',len(target)-literal_start)+target[literal_start:])
    body.append(2)
    compressor=zlib.compressobj(level=9,wbits=-15)
    return MAGIC+compressor.compress(body)+compressor.flush()

def apply_delta(source: bytes, patch: bytes) -> bytes:
    if not patch.startswith(MAGIC):raise ValueError('Invalid patch header')
    try:
        decoder=zlib.decompressobj(wbits=-15)
        body=decoder.decompress(patch[len(MAGIC):])
        if not decoder.eof or decoder.unused_data:raise ValueError('Truncated patch or trailing data')
        expected,=struct.unpack_from('<Q',body)
        if expected>1024*1024*1024:raise ValueError('Output too large')
        out=bytearray()
        pos=8
        while pos<len(body):
            opcode=body[pos];pos+=1
            if opcode==2:
                if pos!=len(body) or len(out)!=expected:raise ValueError('Output size mismatch')
                return bytes(out)
            if opcode==0:
                offset,length=struct.unpack_from('<QI',body,pos);pos+=12
                if offset+length>len(source):raise ValueError('Copy outside source')
                out.extend(source[offset:offset+length])
            elif opcode==1:
                length,=struct.unpack_from('<I',body,pos);pos+=4
                if pos+length>len(body):raise ValueError('Truncated literal')
                out.extend(body[pos:pos+length]);pos+=length
            else:raise ValueError('Unknown opcode')
            if len(out)>expected:raise ValueError('Output exceeds declared size')
        raise ValueError('Missing end marker')
    except (zlib.error,struct.error) as exc:
        raise ValueError('Corrupt patch') from exc

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    parser.add_argument('target',type=Path)
    parser.add_argument('output',type=Path)
    args=parser.parse_args()
    source,target=args.source.read_bytes(),args.target.read_bytes()
    patch=create_delta(source,target)
    if apply_delta(source,patch)!=target:raise RuntimeError('Roundtrip mismatch')
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_bytes(patch)
    print(f'{len(patch):,} bytes; verified target SHA256 {hashlib.sha256(target).hexdigest()}')

if __name__=='__main__':main()
