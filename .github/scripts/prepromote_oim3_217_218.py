from pathlib import Path
import sys
root=Path(sys.argv[1]).resolve()

def once(rel, old, new):
    p=root/rel; s=p.read_text()
    if s.count(old)!=1:
        raise SystemExit(f'{rel}: expected one match for {old!r}, got {s.count(old)}')
    p.write_text(s.replace(old,new,1))

once('CMakeLists.txt','set(PROJECT_VER "2.1.7")','set(PROJECT_VER "2.1.8")')
once('components/oim_board/include/oim_board.hpp','FIRMWARE_VERSION = "2.1.7"','FIRMWARE_VERSION = "2.1.8"')
once('components/oim_board/include/oim_board.hpp','FIRMWARE_NAME = "VS-ESP-IDF-V2.1.7-OIM3-FACTORY-QA"','FIRMWARE_NAME = "VS-ESP-IDF-V2.1.8-OIM3-FACTORY-QA"')
once('components/oim_board/include/oim_board.hpp',
     'inline constexpr unsigned WIFI_PROVISION_TIMEOUT_SECONDS = 120;',
     'inline constexpr unsigned WIFI_PROVISION_TIMEOUT_SECONDS = 120;\ninline constexpr unsigned WIFI_RECONFIG_POWERON_WINDOW_SECONDS = 30;')

p=root/'main/app_main.cpp'; s=p.read_text()
old='''    if (reset_reason == ESP_RST_POWERON) {\n        ESP_LOGI(TAG, "Real power-on: opening Wi-Fi reconfiguration AP for %u seconds",\n                 oim::board::WIFI_PROVISION_TIMEOUT_SECONDS);\n        (void)oim::provision::run(oim::board::WIFI_PROVISION_TIMEOUT_SECONDS);\n        sleep_seconds(1U, "Power-on Wi-Fi provisioning window closed; restarting into telemetry-only wake");\n    }\n'''
new='''    if (reset_reason == ESP_RST_POWERON) {\n        ESP_LOGI(TAG, "Real power-on: opening Wi-Fi reconfiguration AP for %u seconds",\n                 oim::board::WIFI_RECONFIG_POWERON_WINDOW_SECONDS);\n        (void)oim::provision::run(oim::board::WIFI_RECONFIG_POWERON_WINDOW_SECONDS);\n        sleep_seconds(1U, "Power-on Wi-Fi provisioning window closed; restarting into telemetry-only wake");\n    }\n'''
if s.count(old)!=1: raise SystemExit('app power-on block mismatch')
p.write_text(s.replace(old,new,1))

p=root/'components/oim_provision/oim_provision.cpp'; s=p.read_text()
old='''        if ((now - started_ms) >= absolute_limit_seconds * 1000UL) {\n            ESP_LOGW(TAG, "Wi-Fi provisioning absolute session cap reached");\n            break;\n        }\n\n        if (s_client_count.load(std::memory_order_relaxed) > 0U) {\n            client_seen = true;\n            if ((now - s_last_activity_ms.load(std::memory_order_relaxed)) >=\n'''
new='''        if (!client_seen &&\n            (now - started_ms) >= absolute_limit_seconds * 1000UL) {\n            ESP_LOGW(TAG, "Wi-Fi provisioning pre-client session cap reached");\n            break;\n        }\n\n        if (s_client_count.load(std::memory_order_relaxed) > 0U) {\n            if (!client_seen) {\n                client_seen = true;\n                ESP_LOGI(TAG, "Provisioning client acquired; initial no-client timeout cancelled");\n            }\n            if ((now - s_last_activity_ms.load(std::memory_order_relaxed)) >=\n'''
if s.count(old)!=1: raise SystemExit('provision loop mismatch')
p.write_text(s.replace(old,new,1))

p=root/'README.md'; s=p.read_text()
# V2.1.8 patch workflow had inserted a release section before the existing V2.1.7 docs.
if not s.startswith('## V2.1.8 — 30 s power-on provisioning'):
    s='''## V2.1.8 — 30 s power-on provisioning\n\n# VisionSen ESP-IDF V2.1.8 — FACTORY QA\n\nFirmware: `2.1.8`\n\n'''+s
p.write_text(s)
