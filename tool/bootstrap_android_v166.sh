#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/bootstrap_android_v165.sh"

# v1.6.6 source owns the visible version and factory-serial UI directly.
# Normalize any v1.6.5 build-time footer rewrite inherited from the lower layer.
python3 - <<'PYEOF'
from pathlib import Path
p = Path('lib/screens/wifi_provision_screen.dart')
t = p.read_text(encoding='utf-8')
t = t.replace(
    'Mobil v1.6.5+23 • Konum izinsiz Wi-Fi + ağ izin düzeltmesi',
    'Mobil v1.6.6+24 • Üretici seri kimliği salt-okunur',
)
p.write_text(t, encoding='utf-8')
PYEOF

echo "Android v1.6.6 provisioning hazır: factory serial read-only + v1.6.5 network permission fix."
