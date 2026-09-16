from pathlib import Path
import base64
import hashlib
import zlib

ROOT = Path(__file__).resolve().parent
PAYLOAD = ROOT / "payload"
TARGET = Path("factory_pc_tool_v068/visionsen_factory_tool.py")
EXPECTED_SHA256 = "2f6d35020a2b5c0864c1f952dcdc9af8102bfb17a31c5748d14a27821f2b7b03"
EXPECTED_B64_LENGTH = 40872

names = [
    "chunk00.txt",
    "chunk01.txt",
    "chunk02a.txt",
    "chunk02b.txt",
    "chunk02c.txt",
    "chunk02d.txt",
    "chunk02e.txt",
    "chunk03.txt",
    "chunk04.txt",
    "chunk05.txt",
]
parts = []
for name in names:
    p = PAYLOAD / name
    if not p.is_file():
        raise SystemExit(f"Factory 0.6.8 payload chunk missing: {p}")
    parts.append(p.read_text(encoding="ascii").strip())

data = "".join(parts)
if len(data) != EXPECTED_B64_LENGTH:
    raise SystemExit(f"Factory 0.6.8 payload length mismatch: {len(data)} != {EXPECTED_B64_LENGTH}")

try:
    raw = zlib.decompress(base64.b64decode(data, validate=True))
except Exception as exc:
    raise SystemExit(f"Factory 0.6.8 payload decode failed: {exc}") from exc

got = hashlib.sha256(raw).hexdigest()
if got != EXPECTED_SHA256:
    raise SystemExit(f"Factory 0.6.8 payload SHA mismatch: {got} != {EXPECTED_SHA256}")

TARGET.write_bytes(raw)
print(f"Factory 0.6.8 source payload restored: {len(raw)} bytes • SHA256 {got}")
