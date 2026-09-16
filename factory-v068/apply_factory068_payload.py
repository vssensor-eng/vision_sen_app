from pathlib import Path
import base64
import hashlib
import lzma
import subprocess

ROOT = Path(__file__).resolve().parent
TARGET = Path("factory_pc_tool_v068/visionsen_factory_tool.py")
PATCH_FILE = ROOT / "factory068.patch"
EXPECTED_PATCH_SHA256 = "83b7bdf24b42b8646398e162fade1b56ab3588b711431cbf70b927d222c75571"
EXPECTED_TARGET_SHA256 = "2f6d35020a2b5c0864c1f952dcdc9af8102bfb17a31c5748d14a27821f2b7b03"
EXPECTED_B64_LENGTH = 15416

parts = []
for name in ("patch_data_1.txt", "patch_data_2.txt", "patch_data_3.txt"):
    p = ROOT / name
    if not p.is_file():
        raise SystemExit(f"Factory 0.6.8 patch chunk missing: {p}")
    parts.append(p.read_text(encoding="ascii").strip())

data = "".join(parts)
if len(data) != EXPECTED_B64_LENGTH:
    raise SystemExit(f"Factory 0.6.8 patch payload length mismatch: {len(data)} != {EXPECTED_B64_LENGTH}")

try:
    patch = lzma.decompress(base64.b64decode(data, validate=True))
except Exception as exc:
    raise SystemExit(f"Factory 0.6.8 patch decode failed: {exc}") from exc

patch_sha = hashlib.sha256(patch).hexdigest()
if patch_sha != EXPECTED_PATCH_SHA256:
    raise SystemExit(f"Factory 0.6.8 patch SHA mismatch: {patch_sha} != {EXPECTED_PATCH_SHA256}")

PATCH_FILE.write_bytes(patch)
subprocess.run([
    "git", "apply", "--whitespace=nowarn", "--directory=factory_pc_tool_v068", str(PATCH_FILE)
], check=True)

got = hashlib.sha256(TARGET.read_bytes()).hexdigest()
if got != EXPECTED_TARGET_SHA256:
    raise SystemExit(f"Factory 0.6.8 target SHA mismatch: {got} != {EXPECTED_TARGET_SHA256}")

print(f"Factory 0.6.8 patch applied: {len(patch)} bytes • target SHA256 {got}")
