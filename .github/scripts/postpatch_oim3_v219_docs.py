from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()

replacements = {
    'FINAL_RELEASE_CHECKLIST.md': [
        (
            'AES-GCM nonce high-water remains dual-persisted in NVS + SPIFFS; if the next nonce range cannot be durably committed to both stores, OIM3 send fails closed instead of risking nonce reuse.',
            'AES-GCM nonce high-water is dual-persisted in normal `nvs` + dedicated `nonce_state`; if the next nonce range cannot be durably committed to both NVS domains, OIM3 send fails closed instead of risking nonce reuse.'
        ),
    ],
}

for rel, pairs in replacements.items():
    p = root / rel
    text = p.read_text(encoding='utf-8')
    for old, new in pairs:
        if old not in text:
            raise SystemExit(f'{rel}: expected documentation phrase not found: {old}')
        text = text.replace(old, new)
    p.write_text(text, encoding='utf-8')

# Release docs must not describe the retired SPIFFS nonce mirror as current behavior.
for rel in ['FINAL_RELEASE_CHECKLIST.md', 'README.md', 'V2.1.9_PRODUCTION_HARDENING_SUMMARY.md']:
    text = (root / rel).read_text(encoding='utf-8')
    if 'nonce high-water remains dual-persisted in NVS + SPIFFS' in text:
        raise SystemExit(f'{rel}: stale NVS+SPIFFS nonce wording remains')

print('v2.1.9 release documentation consistency: PASS')
