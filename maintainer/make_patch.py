#!/usr/bin/env python3
"""Maintainer tool: builds the minimal patch (only the bytes that differ) from the ORIGINAL partition
images and the MODIFIED ones, mapping 4 KiB blocks to disk LBAs through the LP (dynamic partition) extents.
Usage: make_patch.py super.img backup.img orig_dir mod_dir outdir
  orig_dir/system_b.img,product_b.img  = original logical partitions
  mod_dir/system_b.img,product_b.img   = modified ones
Outputs: outdir/hy300-minimal.bin (new bytes only) and outdir/manifest.txt (LBA, sectors, offset, sha256 orig/new)."""
import struct, hashlib, sys, os
sup, bkp, od, md, out = sys.argv[1:6]
SUPER = 599040  # LBA where the 'super' partition starts on this device
os.makedirs(out, exist_ok=True)
f = open(sup, 'rb'); f.seek(12288 + 65536); h = f.read(256)  # LP metadata, slot 1 (active slot _b)
tl, = struct.unpack('<I', h[44:48]); tabs = struct.unpack('<12I', h[80:128])
f.seek(12288 + 65536 + 256); t = f.read(tl)
po, pn, pe = tabs[0:3]; eo, en, ee = tabs[3:6]
ext = [struct.unpack('<QIQI', t[eo + i * ee:eo + i * ee + 24]) for i in range(en)]
parts = {}
for i in range(pn):
    x = t[po + i * pe:po + i * pe + pe]; nm = x[:36].split(b'\0')[0].decode(); at, fe, ne, gi = struct.unpack('<IIII', x[36:52])
    parts[nm] = [(ext[fe + j][2], ext[fe + j][0]) for j in range(ne)]
bk = open(bkp, 'rb'); blob = bytearray(); lines = []
for name in ('system_b', 'product_b'):
    orig = open(os.path.join(od, name + '.img'), 'rb').read(); new = open(os.path.join(md, name + '.img'), 'rb').read()
    assert len(orig) == len(new)
    chk = bytearray()
    for ph, n in parts[name]:
        bk.seek((SUPER + ph) * 512); chk += bk.read(n * 512)
    assert bytes(chk) == orig, name + ': original image does not match the backup'
    diff = [b for b in range(len(orig) // 4096) if orig[b*4096:(b+1)*4096] != new[b*4096:(b+1)*4096]]
    runs = []
    for b in diff:
        if runs and runs[-1][1] == b: runs[-1][1] = b + 1
        else: runs.append([b, b + 1])
    for a, z in runs:
        pos = a * 8; acc = 0
        for ph, n in parts[name]:
            if pos < acc + n:
                assert z * 8 <= acc + n
                o, nw = orig[a*4096:z*4096], new[a*4096:z*4096]
                lines.append('seg %d %d %d %s %s' % (SUPER + ph + pos - acc, (z - a) * 8, len(blob), hashlib.sha256(o).hexdigest(), hashlib.sha256(nw).hexdigest()))
                blob += nw; break
            acc += n
open(os.path.join(out, 'hy300-minimal.bin'), 'wb').write(blob)
hdr = ['HY300PATCH 1', 'base UI_Veng.projector.20250221.201033', 'patchsha256 ' + hashlib.sha256(blob).hexdigest(), 'segments %d' % len(lines)]
open(os.path.join(out, 'manifest.txt'), 'w').write('\n'.join(hdr + lines) + '\n')
print(len(lines), 'segments,', len(blob) / 1048576, 'MiB, patch sha256', hashlib.sha256(blob).hexdigest()[:16])
