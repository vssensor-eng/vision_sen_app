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
CHUNKS = (
    ("patch_data_1.txt", 7000, "abd5fac9d94b8a25863815a83e621602cea4aeee3e78cb4404ff2df1a3bab995"),
    ("patch_data_2.txt", 7000, "76cfac58336861ec00b4b509c6d6fbde95ddb89dbc82f758f24aa9c1a4e74ec0"),
    ("patch_data_3.txt", 1416, "fd7ae0e4c72b610b94d4731c6fa2284f170c835f89709c85ecb8055d1ec85d2d"),
)

parts = []
for name, expected_len, expected_sha in CHUNKS:
    p = ROOT / name
    if not p.is_file():
        raise SystemExit(f"Factory 0.6.8 patch chunk missing: {p}")
    text = p.read_text(encoding="ascii").strip()
    got_sha = hashlib.sha256(text.encode("ascii")).hexdigest()
    if len(text) != expected_len or got_sha != expected_sha:
        # Connector aktarımında tek bir fazla karakter oluşmuşsa deterministik olarak
        # yalnız beklenen SHA'ya geri dönebilen tek karakteri çıkar.
        repaired = None
        if len(text) == expected_len + 1:
            for i in range(len(text)):
                candidate = text[:i] + text[i + 1:]
                if hashlib.sha256(candidate.encode("ascii")).hexdigest() == expected_sha:
                    repaired = candidate
                    print(f"Factory 0.6.8 patch chunk repaired: {name} extra-char-index={i}")
                    break
        if repaired is None:
            raise SystemExit(
                f"Factory 0.6.8 patch chunk mismatch: {name} len={len(text)} sha={got_sha}"
            )
        text = repaired
    parts.append(text)

data = "".join(parts)
if len(data) != 15416:
    raise SystemExit(f"Factory 0.6.8 patch payload length mismatch after repair: {len(data)}")

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
