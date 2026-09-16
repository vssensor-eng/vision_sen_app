from pathlib import Path
import ast, hashlib, importlib.util, json, sys, tempfile, math
from types import SimpleNamespace

R=Path(__file__).resolve().parents[1]
SRC=R/'visionsen_factory_tool.py'
s=SRC.read_text(encoding='utf-8')
contract=json.loads((R/'protocol/oim3_contract.json').read_text(encoding='utf-8'))
fw=json.loads((R/'firmware/visionsen_firmware_manifest.json').read_text(encoding='utf-8'))

checks={
 'source_clean': not any(R.rglob('__pycache__')) and not any(R.rglob('*.pyc')),
 'version': 'APP_VERSION = "0.6.8"' in s,
 'strict_contract': 'SYSTEM_CONTRACT = "VS-OIM3-STRICT-1"' in s,
 'fw_version': 'REQUIRED_FIRMWARE_VERSION = "2.2.1"' in s,
 'nonce_protected': '(0x18000, 0x20000, "nonce_state")' in s,
 'storage_protected': '(0x320000, 0x400000, "storage/queue")' in s,
 'factory_data_partition': '(0x12000, 0x18000, "factory_data")' in s,
 'split_production_write': all(x in s for x in ('Kimliği Cihaza Yaz','Donanımı Cihaza Yaz','def write_identity_only','def write_hardware','production_identity')),
 'production_read_removed': 'self.read_button' not in s,
 'service_direct_flash_read': 'def _read_factory_record_from_flash' in s and '"read-flash", "0x12000", "0x6000"' in s,
 'nvs_parser': 'def parse_factory_nvs_partition' in s and 'typ == 0x21' in s and 'typ == 0x04' in s,
 'service_explicit_fields': all(x in s for x in ('service_serial_var','service_hwid_var','service_schema_var','service_hwrev_var','service_prod_var')),
 'service_read_reset': 'def service_read_device' in s and 'reset=True' in s,
 'service_independent_firmware': 'service_ready = connected and self._workflow_state["service_read"]' in s,
 'manifest_test_enriched': 'result = self._enrich_result(parse_log(text))' in s,
 'last_written_manifest': '"manifest_sensors": tuple(sensor_keys)' in s and '"manifest_hash": manifest_hash_hex.lower()' in s,
 'qr_after_test': 'QR/etiket üretimi son test PASS sonrasına bırakıldı.' in s and 'self.qr_button, connected and self._workflow_state["production_test"]' in s,
 'test_turkish': 'fields = ["Kimlik", "Donanım", "Yazılım", "Sensör", "Sıcaklık", "Nem", "Çiğ Noktası", "Batarya", "OIM3"]' in s,
 'charge_removed_ui': '"Şarj"' not in s,
 'scrollable_tabs': 'def make_scroll_tab()' in s and 'orient="vertical", command=canvas.yview' in s,
 'resizable_log': 'self.main_pane = tk.PanedWindow' in s and 'height=24' in s and 'sash_place' in s,
 'pt1000_removed': 'PT1000' not in s,
 'manifest_autobump': 'next_manifest_version_for_sensor_change' in s and 'donanım kaydı otomatik' in s,
 'production_v1': 'manifest_version = 1' in s and 'Üretim hattında cihaz henüz teslim edilmedi' in s,
 'service_preserves_storage': 'KORUNACAK (servis donanım güncellemesi)' in s,
 'com_controls': all(x in s for x in ('Yenile','Bağlan','Bağlantıyı Kes','self.port_combo')),
 'max_channels': contract.get('max_channels_per_packet')==32,
 'secret_len': int(contract.get('provision_secret',{}).get('length') or 0)==8,
 'fw_manifest_version': fw.get('firmware_version')=='2.2.1',
 'fw_manifest_contract': fw.get('system_contract')=='VS-OIM3-STRICT-1',
}
for name,expected in (fw.get('sha256') or {}).items():
    p=R/'firmware'/name
    checks[f'hash_{name}']=p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==expected
try:
    ast.parse(s); checks['python_syntax']=True
except Exception:
    checks['python_syntax']=False

# Runtime tests
try:
    spec=importlib.util.spec_from_file_location('visionsen_factory_tool_validation',SRC)
    mod=importlib.util.module_from_spec(spec); assert spec and spec.loader
    sys.modules[spec.name]=mod; spec.loader.exec_module(mod)

    length,alphabet=mod.provision_secret_policy()
    valid=alphabet[:length]
    checks['secret_runtime']=mod.valid_provision_secret(valid)
    checks['manifest_autobump_runtime']=mod.next_manifest_version_for_sensor_change(1,1,('SHT45:1',),('SHT45:1','BATTERY:1'))==2

    # Build a minimal NVS page using the documented 32-byte entry layout.
    page=bytearray(b'\xff'*4096)
    cursor=0
    def put_entry(ns,typ,key,value):
        nonlocal_dummy=None
        global cursor
        keyb=key.encode('ascii')+b'\x00'
        assert len(keyb)<=16
        if typ==0x21:
            payload=value.encode('utf-8')+b'\x00'
            span=1+math.ceil(len(payload)/32)
        else:
            payload=b''; span=1
        e=bytearray(b'\xff'*32)
        e[0]=ns; e[1]=typ; e[2]=span; e[3]=0xff
        e[8:8+len(keyb)]=keyb
        if typ==0x01:
            e[24]=int(value)
        elif typ==0x04:
            e[24:28]=int(value).to_bytes(4,'little')
        elif typ==0x21:
            e[24:26]=len(payload).to_bytes(2,'little')
        off=64+cursor*32
        page[off:off+32]=e
        if typ==0x21:
            padded=payload+b'\xff'*(32*(span-1)-len(payload))
            page[off+32:off+span*32]=padded
        cursor += span
    put_entry(0,0x01,'identity',1)
    put_entry(1,0x04,'schema',2)
    put_entry(1,0x21,'serial','ESP-001')
    put_entry(1,0x21,'hwrev','OIM3-R1')
    put_entry(1,0x21,'prod_date','2026-09-17')
    put_entry(1,0x21,'prov_secret',valid)
    put_entry(0,0x01,'manifest',2)
    put_entry(2,0x04,'schema',1)
    put_entry(2,0x21,'serial','ESP-001')
    put_entry(2,0x04,'version',2)
    sensors='BATTERY:1,SHT45:1'
    mh=mod.manifest_hash('ESP-001',2,sensors.split(','))
    put_entry(2,0x21,'sensors',sensors)
    put_entry(2,0x21,'hash',mh)
    blob=bytes(page)+b'\xff'*(0x6000-4096)
    rec=mod.parse_factory_nvs_partition(blob)
    checks['nvs_identity_runtime']=rec['identity']['serial']=='ESP-001' and rec['identity']['hwrev']=='OIM3-R1' and rec['identity']['schema']==2
    checks['nvs_manifest_runtime']=rec['manifest']['version']==2 and rec['manifest']['sensors']==sensors and rec['manifest']['hash']==mh

    line='W (555) visionsen: VSFACT1 serial=ESP-001 hw_id=6809479C5A54 fw=2.2.1 schema=2 sensor_init=OK sht45=PASS temp_c=23.96 humidity_pct=62.29 dew_point_c=16.30 battery_status=OK battery_v=3.91 charging=UNKNOWN'
    tr=mod.parse_log(line)
    app=object.__new__(mod.VisionSenFactoryApp)
    merged=app._merge_factory_record_into_result(tr,rec)
    checks['merged_identity_runtime']=merged.identity_ok and merged.hw_rev=='OIM3-R1' and merged.production_date=='2026-09-17'
    checks['merged_manifest_runtime']=merged.manifest_ok and merged.manifest_version==2 and merged.overall=='PASS'

    app2=object.__new__(mod.VisionSenFactoryApp)
    app2.last_written={'serial':'ESP-001','hw_rev':'OIM3-R1','production_date':'2026-09-17','factory_schema':'2','provisioning_secret':valid,'manifest_version':1,'manifest_hash':mod.manifest_hash('ESP-001',1,('SHT45:1',)),'manifest_sensors':('SHT45:1',)}
    app2.settings=SimpleNamespace(report_csv=str(R/'__does_not_exist.csv'))
    tr2=mod.parse_log('VSFACT1 serial=ESP-001 hw_id=6809479C5A54 fw=2.2.1 schema=2 sensor_init=OK sht45=PASS temp_c=24.0 humidity_pct=50.0 dew_point_c=13.0 battery_status=NOT_READ battery_v=NA charging=UNKNOWN')
    tr2=app2._enrich_result(tr2)
    checks['production_manifest_runtime']=tr2.manifest_ok and tr2.overall=='PASS' and tr2.hw_rev=='OIM3-R1'
except Exception as exc:
    checks['runtime_tests']=False
    print('runtime detail:',repr(exc))
else:
    checks['runtime_tests']=True

failed=[k for k,v in checks.items() if not v]
for k,v in checks.items(): print(f'{k}: {"PASS" if v else "FAIL"}')
if failed:
    raise SystemExit('FACTORY 0.6.8 PRODUCTION GATE FAIL: '+', '.join(failed))
print('FACTORY 0.6.8 PRODUCTION GATE PASS')
