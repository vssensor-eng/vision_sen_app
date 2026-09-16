from pathlib import Path
import ast
import hashlib
import importlib.util
import json
import sys
from types import SimpleNamespace

R = Path(__file__).resolve().parents[1]
SRC = R / 'visionsen_factory_tool.py'
s = SRC.read_text(encoding='utf-8')
contract = json.loads((R / 'protocol/oim3_contract.json').read_text(encoding='utf-8'))
fw = json.loads((R / 'firmware/visionsen_firmware_manifest.json').read_text(encoding='utf-8'))

checks = {
    'source_clean': not any(R.rglob('__pycache__')) and not any(R.rglob('*.pyc')),
    'version': 'APP_VERSION = "0.6.6"' in s,
    'strict_contract': 'SYSTEM_CONTRACT = "VS-OIM3-STRICT-1"' in s,
    'fw_version': 'REQUIRED_FIRMWARE_VERSION = "2.2.1"' in s,
    'firmware_result_gate': 'if self.firmware != REQUIRED_FIRMWARE_VERSION:' in s,
    'nonce_protected': '(0x18000, 0x20000, "nonce_state")' in s,
    'manifest_rehash': 'secrets.compare_digest(expected, (self.manifest_hash or "").strip().lower())' in s,
    'callback_errors': 'def report_callback_exception' in s,
    'save_without_connection': 'def save_report(self):\n        try:\n            r = self.last_result' in s,
    'csv_safe': 'def _csv_safe' in s,
    'runtime_contract_load': 'def load_protocol_contract()' in s and 'provision_secret_policy()' in s,
    'secret_not_hardcoded_in_tool': 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' not in s and 'A-Za-z0-9' not in s,
    'com_cancel_read': 'cancel_read = getattr(ser, "cancel_read", None)' in s,
    'com_reenumeration': 'def _resolve_physical_port' in s and 'def _refresh_ports_after_reset' in s,
    'max_channels': contract.get('max_channels_per_packet') == 32,
    'secret_len': int(contract.get('provision_secret', {}).get('length') or 0) == 8,
    'fw_manifest_version': fw.get('firmware_version') == '2.2.1',
    'fw_manifest_contract': fw.get('system_contract') == 'VS-OIM3-STRICT-1',
    'approved_manifest_gate': 'def _approved_firmware_manifest' in s and 'def _approved_firmware_hashes' in s,
    'external_zip_exact_hash_gate': 'onaylı VisionSen final build ile eşleşmiyor' in s and 'approved_hashes = self._approved_firmware_hashes()' in s,
    'external_bin_exact_hash_gate': 'approved_sha = str(self._approved_firmware_hashes().get("visionsen_oim3.bin")' in s,
    'manifest_sensor_change_autobump': 'next_manifest_version_for_sensor_change' in s and 'Device Manifest otomatik' in s,
    'service_manifest_preserves_storage': 'servis manifest güncellemesi: storage/queue korundu' in s,
    'production_service_tabs': 'self.workflow_tabs.add(prod, text="ÜRETİM")' in s and 'self.workflow_tabs.add(service, text="SERVİS")' in s,
    'ordered_workflow_gates': 'production_firmware' in s and 'production_written' in s and 'service_read' in s and 'service_written' in s and 'def _refresh_workflow_controls' in s,
    'com_controls_preserved': all(x in s for x in ('Yenile', 'Bağlan', 'Bağlantıyı Kes', 'self.port_combo')),
    'progress_in_connection_area': 'self.operation_progress = ttk.Progressbar(conn' in s and 'ttk.Progressbar(fw' not in s,
    'log_always_visible': 'self.log_frame.grid(row=1, column=0, sticky="nsew"' in s and 'Logu Göster / Gizle' not in s and 'def _toggle_log' not in s,
    'log_taller': 'height=18' in s,
    'window_resizable_layout': 'root.rowconfigure(3, weight=1)' in s and 'self.log_frame.rowconfigure(0, weight=1)' in s,
    'identity_single_row': all(x in s for x in ('lbl(ident, "Seri No").grid(row=0', 'lbl(ident, "HW Rev").grid(row=0', 'lbl(ident, "Üretim Tarihi").grid(row=0', 'lbl(ident, "Kurulum Kodu").grid(row=0')),
    'identity_buttons_right_row': 'actions.grid(row=1, column=0, columnspan=8, sticky="e"' in s and 'self.write_identity_button.pack(side="left"' in s,
    'pt1000_removed': 'PT1000' not in s,
    'physical_sensor_catalog': 'PHYSICAL_SENSOR_CATALOG' in s and '"SHT45:1"' in s and '"BATTERY:1"' in s,
    'sensor_model_ui': 'text="SHT45"' in s and 'Sıcaklık • Nem • Çiğ Noktası' in s and 'text="Battery ADC"' in s,
    'dew_point_result_key': 'self.test_labels["Çiğ Noktası"]' in s and 'self.test_labels["Çiy"]' not in s,
    'sensor_result_key_fixed': 'self.test_labels["Sensör"]' in s and 'self.test_labels["SHT45"]' not in s,
    'new_device_default_sht45_only': 'self.manifest_battery_var = tk.BooleanVar(value=False)' in s and 'Yeni cihaz • SHT45 varsayılan seçildi' in s,
    'manifest_revision_readonly_auto': 'Manifest Revizyonu' in s and 'manifest_version_display' in s and 'Sürüm +1' not in s and 'manifest_version_entry' not in s,
    'empty_selection_ui_safe': 'def _selected_manifest_sensor_keys(self, *, allow_empty: bool = False)' in s and 'Manifest bekliyor: en az bir fiziksel sensör seçin.' in s,
    'empty_selection_button_gate': 'prod_has_sensor' in s and 'service_has_sensor' in s,
    'service_auto_read_ready': 'Cihaz bağlantıda otomatik okundu. Servis işlemleri etkin.' in s,
}

for name, expected in (fw.get('sha256') or {}).items():
    p = R / 'firmware' / name
    checks[f'hash_{name}'] = p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest() == expected

try:
    ast.parse(s)
    checks['python_syntax'] = True
except SyntaxError:
    checks['python_syntax'] = False

try:
    spec = importlib.util.spec_from_file_location('visionsen_factory_tool_validation', SRC)
    mod = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    sys.modules[spec.name] = mod
    spec.loader.exec_module(mod)

    length, alphabet = mod.provision_secret_policy()
    valid_secret = alphabet[:length]
    invalid_char = next((c for c in '0O1Ilaz' if c not in alphabet), '|')
    checks['runtime_secret_accepts_contract'] = mod.valid_provision_secret(valid_secret)
    checks['runtime_secret_rejects_outside_alphabet'] = not mod.valid_provision_secret(invalid_char * length)
    checks['manifest_autobump_runtime'] = mod.next_manifest_version_for_sensor_change(1, 1, ('SHT45:1',), ('SHT45:1','BATTERY:1')) == 2
    checks['manifest_same_sensors_no_bump_runtime'] = mod.next_manifest_version_for_sensor_change(1, 1, ('SHT45:1',), ('SHT45:1',)) == 1
    checks['sensor_display_sht45_runtime'] = mod.sensor_display_text('SHT45:1') == 'SHT45 — Sıcaklık • Nem • Çiğ Noktası'
    checks['sensor_display_battery_runtime'] = mod.sensor_display_text('BATTERY:1') == 'Battery ADC — Batarya Gerilimi'
    try:
        mod.normalize_manifest_sensor_keys(('PT1000:1',))
        checks['pt1000_rejected_runtime'] = False
    except ValueError:
        checks['pt1000_rejected_runtime'] = True

    app = object.__new__(mod.VisionSenFactoryApp)
    app.manifest_sht45_var = SimpleNamespace(get=lambda: False)
    app.manifest_battery_var = SimpleNamespace(get=lambda: False)
    checks['empty_selection_allow_runtime'] = app._selected_manifest_sensor_keys(allow_empty=True) == ()
    try:
        app._selected_manifest_sensor_keys()
        checks['empty_selection_strict_runtime'] = False
    except ValueError:
        checks['empty_selection_strict_runtime'] = True

    serial_no = 'ESP-1'
    sensors = ('SHT45:1',)
    mh = mod.manifest_hash(serial_no, 1, sensors)
    common = dict(serial=serial_no, hw_id='AA:BB:CC:DD:EE:FF', factory_schema='2', firmware='2.2.1',
                  sht45_found=True, temperature='24.0', humidity='45.0', manifest_serial=serial_no,
                  manifest_version=1, manifest_hash=mh, manifest_sensors=sensors)
    checks['current_fw_passes_result_gate'] = mod.TestResult(**common).overall == 'PASS'
    common['firmware'] = '2.1.12'
    checks['old_fw_fails_result_gate'] = mod.TestResult(**common).overall == 'FAIL'

    app2 = object.__new__(mod.VisionSenFactoryApp)
    app2._last_port_identity = {'device': 'COM3', 'serial_number': 'USB123', 'vid': 0x303A, 'pid': 0x1001, 'location': '1-2'}
    saved_list_ports = mod.list_ports
    mod.list_ports = SimpleNamespace(comports=lambda: [SimpleNamespace(device='COM7', serial_number='USB123', vid=0x303A, pid=0x1001, location='1-2')])
    try:
        checks['com_reenumeration_runtime'] = app2._resolve_physical_port('COM3') == 'COM7'
    finally:
        mod.list_ports = saved_list_ports
except Exception as exc:
    checks['runtime_logic_tests'] = False
    print(f'runtime_logic_tests detail: {exc}', file=sys.stderr)

failed = []
for k,v in checks.items():
    print(f'{k}: {"PASS" if v else "FAIL"}')
    if not v:
        failed.append(k)
if failed:
    print('FACTORY PRODUCTION GATE FAIL: ' + ', '.join(failed), file=sys.stderr)
    raise SystemExit(1)
print('FACTORY PRODUCTION GATE PASS')
