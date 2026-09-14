from pathlib import Path
import base64
import hashlib
import zlib

parts = sorted(Path('.mobile_v169').glob('payload_part*.txt'))
if len(parts) != 4:
    raise SystemExit(f'expected 4 payload parts, found {len(parts)}')
encoded = ''.join(p.read_text(encoding='ascii').strip() for p in parts)
raw = zlib.decompress(base64.b64decode(encoded))
expected = 'e0ea13ccea09dc66ae40ba1cff351dca9e40465f0c96ad9687fc97625d644d8e'
actual = hashlib.sha256(raw).hexdigest()
if actual != expected:
    raise SystemExit(f'payload sha mismatch: {actual}')
code = compile(raw, '.mobile_v169/mobile169_apply.py', 'exec')
exec(code, {'__name__': '__main__'})

# Flutter analyzer: Navigator must not reuse BuildContext across the async bootstrap gap.
p = Path('lib/screens/wifi_provision_screen.dart')
s = p.read_text(encoding='utf-8')
old = "    if (!await _ensureProvisioningBootstrap()) return;\n\n    final qr = await Navigator.of(context).push<ProvisioningQrData>(\n"
new = "    if (!await _ensureProvisioningBootstrap()) return;\n    if (!mounted) return;\n\n    final qr = await Navigator.of(context).push<ProvisioningQrData>(\n"
if old in s:
    s = s.replace(old, new, 1)
elif new not in s:
    raise SystemExit('mounted lifecycle guard patch target missing')
p.write_text(s, encoding='utf-8')

print(f'VisionSen mobile v1.6.9 payload applied, sha256={actual}')
print('Applied mounted lifecycle guard before QR navigation')
