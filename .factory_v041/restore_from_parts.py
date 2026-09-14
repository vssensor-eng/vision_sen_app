from pathlib import Path
import base64
import hashlib
import zlib

parts = sorted(Path('.factory_v041').glob('source_part*.txt'))
if len(parts) != 7:
    raise SystemExit(f'expected 7 source parts, found {len(parts)}')

encoded = ''.join(p.read_text(encoding='ascii').strip() for p in parts)
raw = zlib.decompress(base64.b64decode(encoded))
expected = '5440d63ec585fbf77e46ea4e237c529ae21bfb92fe76536b38748f66debf3c9b'
actual = hashlib.sha256(raw).hexdigest()
if actual != expected:
    raise SystemExit(f'source hash mismatch: {actual}')

out = Path('factory_pc_tool_v041/visionsen_factory_tool.py')
out.parent.mkdir(parents=True, exist_ok=True)
out.write_bytes(raw)
print(f'wrote {out} sha256={actual}')
