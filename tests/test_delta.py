from pathlib import Path
import sys,unittest,zlib,struct
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from make_delta import create_delta,apply_delta

class DeltaTests(unittest.TestCase):
    def test_empty(self):
        self.assertEqual(apply_delta(b'',create_delta(b'',b'')),b'')
    def test_insert_delete_move(self):
        source=bytes(range(256))*200
        target=b'new header'+source[1000:9000]+b'new literal'+source[20000:]+source[:1000]
        self.assertEqual(apply_delta(source,create_delta(source,target)),target)
    def test_unchanged_is_small(self):
        source=bytes(range(256))*10000
        patch=create_delta(source,source)
        self.assertLess(len(patch),1024)
        self.assertEqual(apply_delta(source,patch),source)
    def test_binary_literal(self):
        target=bytes(range(256))
        self.assertEqual(apply_delta(b'',create_delta(b'',target)),target)
    def test_invalid_header(self):
        with self.assertRaises(ValueError): apply_delta(b'',b'not a patch')
    def test_copy_out_of_bounds(self):
        body=struct.pack('<Q',64)+b'\x00'+struct.pack('<QI',100,64)+b'\x02'
        compressor=zlib.compressobj(wbits=-15)
        patch=b'CTPDIFF1'+compressor.compress(body)+compressor.flush()
        with self.assertRaises(ValueError): apply_delta(b'x',patch)
    def test_truncated(self):
        patch=create_delta(b'original',b'new data')
        with self.assertRaises(ValueError): apply_delta(b'original',patch[:-4])

if __name__=='__main__': unittest.main()
