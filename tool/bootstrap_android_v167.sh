#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/bootstrap_android_v165.sh"

# v1.6.7 source owns factory-secret UI. Normalize any lower-layer footer rewrite.
python3 - <<'PYEOF'
from pathlib import Path
p = Path('lib/screens/wifi_provision_screen.dart')
t = p.read_text(encoding='utf-8')
for old in (
    'Mobil v1.6.5+23 • Konum izinsiz Wi-Fi + ağ izin düzeltmesi',
    'Mobil v1.6.6+24 • Üretici seri kimliği salt-okunur',
):
    t = t.replace(old, 'Mobil v1.6.7+25 • Cihaza özel provisioning secret')
p.write_text(t, encoding='utf-8')
PYEOF

echo "Android v1.6.7 provisioning hazır: device-specific factory secret + no-location Wi-Fi + v1.6.5 network permission fix."
