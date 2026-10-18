#!/usr/bin/env python3
"""Validate generated GLB geometry, manifest, slots and size without dependencies."""
import json
import math
import struct
from pathlib import Path

root = Path(__file__).resolve().parent.parent
asset_dir = root / 'assets' / 'hero'
manifest = json.loads((asset_dir/'manifest.json').read_text(encoding='utf8'))
assert len(manifest['parts']) == 21, 'Expect body, armor, cloak and weapon as 21 independent GLBs'
seen=set();tris=0
for part in manifest['parts']:
    assert part['name'] not in seen
    seen.add(part['name'])
    binary=(asset_dir/part['file']).read_bytes()
    assert len(binary)>200 and binary[:4]==b'glTF'
    magic,version,total = struct.unpack_from('<4sII',binary)
    assert version==2 and total==len(binary)
    json_size,chunk_type = struct.unpack_from('<I4s',binary,12)
    assert chunk_type==b'JSON'
    document=json.loads(binary[20:20+json_size])
    assert document['asset']['version']=='2.0'
    assert document['meshes'][0]['name']==part['name']
    binary_size,marker=struct.unpack_from('<I4s',binary,20+json_size)
    assert marker==b'BIN\x00'
    assert binary_size==document['buffers'][0]['byteLength'] or binary_size-document['buffers'][0]['byteLength']<=3
    for primitive in document['meshes'][0]['primitives']:
        pos=document['accessors'][primitive['attributes']['POSITION']]
        norm=document['accessors'][primitive['attributes']['NORMAL']]
        assert pos['count']==norm['count'] and pos['count']%3==0
        assert all(math.isfinite(v) for v in pos['min']+pos['max'])
        assert all(lo<=hi for lo,hi in zip(pos['min'],pos['max']))
        tris+=pos['count']//3
assert tris==sum(p['triangles'] for p in manifest['parts'])
required={'body','chest','waist','head','shoulder_L','shoulder_R', 'arm_L', 'arm_R', 'leg_L','leg_R','cloak','weapon'}
assert required <= {x['slot'] for x in manifest['parts']}
print('VALID:',len(seen),'independent GLB assets,',tris,'triangles')