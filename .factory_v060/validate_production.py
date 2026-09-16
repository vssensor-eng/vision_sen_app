from pathlib import Path
import json, re, sys, hashlib, ast
R=Path(__file__).resolve().parents[1]
s=(R/'visionsen_factory_tool.py').read_text(encoding='utf-8')
contract=json.loads((R/'protocol/oim3_contract.json').read_text(encoding='utf-8'))
fw=json.loads((R/'firmware/visionsen_firmware_manifest.json').read_text(encoding='utf-8'))
checks={
 'version':'APP_VERSION = "0.6.0"' in s,
 'strict_contract':'SYSTEM_CONTRACT = "VS-OIM3-STRICT-1"' in s,
 'fw_version':'REQUIRED_FIRMWARE_VERSION = "2.2.0"' in s,
 'nonce_protected':'(0x18000, 0x20000, "nonce_state")' in s,
 'manifest_rehash':'secrets.compare_digest(expected, (self.manifest_hash or "").strip().lower())' in s,
 'callback_errors':'def report_callback_exception' in s,
 'save_without_connection':'def save_report(self):\n        try:\n            r = self.last_result' in s,
 'csv_safe':'def _csv_safe' in s,
 'last_written':'self.last_written = {' in s,
 'max_channels':contract.get('max_channels_per_packet')==32,
 'secret_len':contract.get('provision_secret',{}).get('length')==8,
 'secret_alphabet':contract.get('provision_secret',{}).get('alphabet')=='ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
 'fw_manifest_version':fw.get('firmware_version')=='2.2.0',
 'fw_manifest_contract':fw.get('system_contract')=='VS-OIM3-STRICT-1',
}
for name, expected in (fw.get('sha256') or {}).items():
 p=R/'firmware'/name
 checks[f'hash_{name}']=p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==expected
bad=[k for k,v in checks.items() if not v]
for k,v in checks.items(): print(f'{k}: {"PASS" if v else "FAIL"}')
if re.search(r'2\.1\.12|v2\.1\.7|legacy', s, re.I):
 bad.append('old_version_or_legacy_text')
try: ast.parse(s)
except SyntaxError as e: bad.append(f'python_syntax:{e}')
if bad:
 print('FACTORY PRODUCTION GATE FAIL:', ', '.join(bad)); sys.exit(1)
print('FACTORY PRODUCTION GATE PASS')
