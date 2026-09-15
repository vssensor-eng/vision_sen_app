from pathlib import Path
import re
import sys
root=Path(sys.argv[1]).resolve()

def rep(rel, old, new, count=1):
    p=root/rel
    s=p.read_text()
    c=s.count(old)
    if c < count:
        raise SystemExit(f'{rel}: wanted >= {count} of {old!r}, got {c}')
    p.write_text(s.replace(old,new,count))

def rerep(rel, pat, repl, count=0, flags=0):
    p=root/rel; s=p.read_text()
    ns,n=re.subn(pat,repl,s,count=count,flags=flags)
    if n==0: raise SystemExit(f'{rel}: regex no match {pat}')
    p.write_text(ns)
    return n

# Version + firmware identity
rep('CMakeLists.txt','set(PROJECT_VER "2.1.8")','set(PROJECT_VER "2.1.9")')
rep('components/oim_board/include/oim_board.hpp','FIRMWARE_VERSION = "2.1.8"','FIRMWARE_VERSION = "2.1.9"')
rep('components/oim_board/include/oim_board.hpp','FIRMWARE_NAME = "VS-ESP-IDF-V2.1.8-OIM3-FACTORY-QA"','FIRMWARE_NAME = "VS-ESP-IDF-V2.1.9-OIM3-PRODUCTION"')

# Partition: use previously unused 0x18000..0x1ffff for an independent nonce NVS mirror.
p=root/'partitions.csv'; s=p.read_text()
needle='factory_data, data, nvs,     0x12000,  0x6000,\nota_0,       app,  ota_0,   0x20000,  0x180000,'
repl='factory_data, data, nvs,     0x12000,  0x6000,\nnonce_state, data, nvs,     0x18000,  0x8000,\nota_0,       app,  ota_0,   0x20000,  0x180000,'
if needle not in s: raise SystemExit('partition insertion point missing')
p.write_text(s.replace(needle,repl,1))

# New nonce component: main NVS + independent nonce_state partition, no SPIFFS dependency.
nonce_dir=root/'components/oim_nonce'; (nonce_dir/'include').mkdir(parents=True,exist_ok=True)
(nonce_dir/'CMakeLists.txt').write_text('''idf_component_register(\n    SRCS "oim_nonce.cpp"\n    INCLUDE_DIRS "include"\n    REQUIRES nvs_flash log\n)\n''')
(nonce_dir/'include/oim_nonce.hpp').write_text('''#pragma once\n\n#include <cstdint>\n\nnamespace oim::nonce {\n\n// Reserve [start, end) durably before any AES-GCM nonce from the block is used.\n// The high-water mark is committed independently to the normal NVS partition\n// and the dedicated nonce_state NVS partition.\nbool reserve_block(uint64_t block_size, uint64_t &start, uint64_t &end);\n\n} // namespace oim::nonce\n''')
(nonce_dir/'oim_nonce.cpp').write_text(r'''#include "oim_nonce.hpp"

#include <algorithm>
#include <cstdint>
#include <limits>

#include "esp_err.h"
#include "esp_log.h"
#include "nvs.h"
#include "nvs_flash.h"

namespace oim::nonce {
namespace {
constexpr const char *TAG = "oim_nonce";
constexpr const char *PRIMARY_NAMESPACE = "oimnonce";
constexpr const char *MIRROR_PARTITION = "nonce_state";
constexpr const char *MIRROR_NAMESPACE = "oimnonce";
constexpr const char *NEXT_KEY = "next";

bool s_mirror_init_attempted = false;
bool s_mirror_ready = false;

bool ensure_mirror_partition()
{
    if (s_mirror_init_attempted) return s_mirror_ready;
    s_mirror_init_attempted = true;
    const esp_err_t err = nvs_flash_init_partition(MIRROR_PARTITION);
    if (err != ESP_OK) {
        // Never erase nonce_state automatically. Losing the last surviving
        // high-water copy can permit AES-GCM nonce reuse after another fault.
        ESP_LOGE(TAG, "Dedicated nonce partition init failed: %s; automatic erase REFUSED",
                 esp_err_to_name(err));
        return false;
    }
    s_mirror_ready = true;
    return true;
}

bool read_next(const char *partition, uint64_t &value, bool &found)
{
    value = 1ULL;
    found = false;
    nvs_handle_t handle{};
    esp_err_t err = partition
        ? nvs_open_from_partition(partition, MIRROR_NAMESPACE, NVS_READONLY, &handle)
        : nvs_open(PRIMARY_NAMESPACE, NVS_READONLY, &handle);
    if (err == ESP_ERR_NVS_NOT_FOUND) return true;
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Nonce high-water namespace open failed (%s): %s",
                 partition ? partition : "nvs", esp_err_to_name(err));
        return false;
    }
    uint64_t next = 1ULL;
    err = nvs_get_u64(handle, NEXT_KEY, &next);
    nvs_close(handle);
    if (err == ESP_ERR_NVS_NOT_FOUND) return true;
    if (err != ESP_OK || next < 1ULL) {
        ESP_LOGE(TAG, "Nonce high-water read failed/invalid (%s): %s",
                 partition ? partition : "nvs", esp_err_to_name(err));
        return false;
    }
    value = next;
    found = true;
    return true;
}

bool commit_next(const char *partition, uint64_t value)
{
    nvs_handle_t handle{};
    esp_err_t err = partition
        ? nvs_open_from_partition(partition, MIRROR_NAMESPACE, NVS_READWRITE, &handle)
        : nvs_open(PRIMARY_NAMESPACE, NVS_READWRITE, &handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Nonce high-water namespace write-open failed (%s): %s",
                 partition ? partition : "nvs", esp_err_to_name(err));
        return false;
    }
    err = nvs_set_u64(handle, NEXT_KEY, value);
    if (err == ESP_OK) err = nvs_commit(handle);
    nvs_close(handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Nonce high-water commit failed (%s): %s",
                 partition ? partition : "nvs", esp_err_to_name(err));
        return false;
    }
    return true;
}
} // namespace

bool reserve_block(uint64_t block_size, uint64_t &start, uint64_t &end)
{
    start = 0ULL;
    end = 0ULL;
    if (block_size == 0ULL || !ensure_mirror_partition()) return false;

    uint64_t primary_next = 1ULL;
    uint64_t mirror_next = 1ULL;
    bool primary_found = false;
    bool mirror_found = false;
    if (!read_next(nullptr, primary_next, primary_found) ||
        !read_next(MIRROR_PARTITION, mirror_next, mirror_found)) {
        return false;
    }

    // V2.1.8 wrote the default-NVS copy before its SPIFFS mirror, therefore the
    // default NVS high-water is a safe migration floor. The new mirror starts in
    // the previously unused 0x18000 partition and no longer depends on SPIFFS.
    uint64_t first = 1ULL;
    if (primary_found) first = std::max(first, primary_next);
    if (mirror_found) first = std::max(first, mirror_next);
    if (first > std::numeric_limits<uint64_t>::max() - block_size) {
        ESP_LOGE(TAG, "Nonce counter exhausted");
        return false;
    }
    const uint64_t next = first + block_size;

    // Advance BOTH durable stores before exposing the block. If power is lost
    // between commits, max(primary, mirror) skips forward on the next boot.
    if (!commit_next(nullptr, next)) return false;
    if (!commit_next(MIRROR_PARTITION, next)) {
        ESP_LOGE(TAG, "Dedicated nonce mirror commit failed; primary reservation intentionally left unused");
        return false;
    }

    start = first;
    end = next;
    if (!mirror_found && primary_found) {
        ESP_LOGW(TAG, "Dedicated nonce mirror initialized from primary high-water=%llu",
                 static_cast<unsigned long long>(primary_next));
    }
    return true;
}

} // namespace oim::nonce
''')

# OIM3 nonce allocator now uses dedicated nonce component.
p=root/'components/oim_oim3/oim_oim3.cpp'; s=p.read_text()
s=s.replace('#include "oim_queue.hpp"\n','#include "oim_nonce.hpp"\n')
pat=r'''bool reserve_nonce_block\(\)\n\{.*?\n\}\n\nbool make_nonce'''
new=r'''bool reserve_nonce_block()
{
    uint64_t start = 0ULL;
    uint64_t next = 0ULL;
    if (!oim::nonce::reserve_block(NONCE_BLOCK_SIZE, start, next)) {
        ESP_LOGE(TAG, "Could not durably reserve AES-GCM nonce block");
        return false;
    }
    s_nonce_next = start;
    s_nonce_end = next;
    s_nonce_rtc_magic = NONCE_RTC_MAGIC; // commit last
    return true;
}

bool make_nonce'''
ns,n=re.subn(pat,new,s,count=1,flags=re.S)
if n!=1: raise SystemExit('reserve_nonce_block replace failed')
p.write_text(ns)

p=root/'components/oim_oim3/CMakeLists.txt'; s=p.read_text()
s=s.replace('        oim_led\n        oim_queue\n        oim_sensors','        oim_led\n        oim_nonce\n        oim_sensors')
p.write_text(s)

# Retire SPIFFS nonce mirror API from queue.
p=root/'components/oim_queue/include/oim_queue.hpp'; s=p.read_text()
s=re.sub(r'// Dual-persistence support.*?bool store_nonce_high_water\(uint64_t value\);\n','',s,flags=re.S)
p.write_text(s)
p=root/'components/oim_queue/oim_queue.cpp'; s=p.read_text()
s=s.replace('constexpr const char *NONCE_HWM_FILE = "/oimfs/oim_nonce.hwm";\nconstexpr const char *NONCE_HWM_TMP_FILE = "/oimfs/oim_nonce.tmp";\n','')
s=re.sub(r'constexpr uint32_t NONCE_HWM_MAGIC.*?constexpr uint16_t NONCE_HWM_VERSION = 1U;\n','',s,flags=re.S)
s=re.sub(r'struct NonceHighWaterRecord \{.*?\};\n\n','',s,flags=re.S)
s=re.sub(r'uint32_t nonce_hwm_checksum\(const NonceHighWaterRecord &r\)\n\{.*?\n\}\n\n','',s,flags=re.S)
s=re.sub(r'bool read_nonce_high_water_file\(uint64_t &value, bool &found\)\n\{.*?\n\}\n\nbool write_nonce_high_water_file\(uint64_t value\)\n\{.*?\n\}\n\n','',s,flags=re.S)
s=re.sub(r'bool load_nonce_high_water\(uint64_t &value, bool &found\)\n\{.*?\n\}\n\nbool store_nonce_high_water\(uint64_t value\)\n\{.*?\n\}\n\n','',s,flags=re.S)
p.write_text(s)

# K3: crash-safe rotating backup header; current + previous valid commit.
p=root/'components/oim_queue/oim_queue.cpp'; s=p.read_text()
s=s.replace('constexpr const char *HEADER_TMP_FILE = "/oimfs/oim_queue.tmp";','constexpr const char *HEADER_TMP_FILE = "/oimfs/oim_queue.tmp";\nconstexpr const char *HEADER_PREV_FILE = "/oimfs/oim_queue.prev.hdr";')
s=s.replace('#include <sys/stat.h>','#include <sys/stat.h>\n#include <unistd.h>')
old='''bool read_backup_header(QueueHeader &h, size_t queue_file_size)\n{\n    FILE *f = std::fopen(HEADER_FILE, "rb");\n    if (!f) return false;\n    const size_t got = std::fread(&h, 1, sizeof(h), f);\n    std::fclose(f);\n    return got == sizeof(h) && header_valid(h, queue_file_size);\n}\n\nbool write_backup_header_atomic(const QueueHeader &h)\n{\n    std::remove(HEADER_TMP_FILE);\n    FILE *f = std::fopen(HEADER_TMP_FILE, "wb");\n    if (!f) return false;\n    const size_t written = std::fwrite(&h, 1, sizeof(h), f);\n    std::fflush(f);\n    std::fclose(f);\n    if (written != sizeof(h)) {\n        std::remove(HEADER_TMP_FILE);\n        return false;\n    }\n\n    std::remove(HEADER_FILE);\n    if (std::rename(HEADER_TMP_FILE, HEADER_FILE) != 0) {\n        std::remove(HEADER_TMP_FILE);\n        return false;\n    }\n    return true;\n}\n'''
new='''bool read_header_file(const char *path, QueueHeader &h, size_t queue_file_size)\n{\n    FILE *f = std::fopen(path, "rb");\n    if (!f) return false;\n    const size_t got = std::fread(&h, 1, sizeof(h), f);\n    std::fclose(f);\n    return got == sizeof(h) && header_valid(h, queue_file_size);\n}\n\nbool read_backup_header(QueueHeader &h, size_t queue_file_size)\n{\n    if (read_header_file(HEADER_FILE, h, queue_file_size)) return true;\n    // If power failed after current->previous but before temp->current, the\n    // previous file is still a complete committed header. Replaying an older\n    // queue position is safe because the server deduplicates packet_id.\n    return read_header_file(HEADER_PREV_FILE, h, queue_file_size);\n}\n\nbool write_backup_header_atomic(const QueueHeader &h)\n{\n    std::remove(HEADER_TMP_FILE);\n    FILE *f = std::fopen(HEADER_TMP_FILE, "wb");\n    if (!f) return false;\n    const size_t written = std::fwrite(&h, 1, sizeof(h), f);\n    const int flush_rc = std::fflush(f);\n    const int sync_rc = (flush_rc == 0) ? ::fsync(::fileno(f)) : -1;\n    std::fclose(f);\n    if (written != sizeof(h) || flush_rc != 0 || sync_rc != 0) {\n        std::remove(HEADER_TMP_FILE);\n        return false;\n    }\n\n    // Never delete the only good backup before the replacement exists. Rotate\n    // current -> previous, then publish temp -> current. A reset between those\n    // renames leaves HEADER_PREV_FILE available to read_backup_header().\n    std::remove(HEADER_PREV_FILE);\n    if (path_exists(HEADER_FILE) && std::rename(HEADER_FILE, HEADER_PREV_FILE) != 0) {\n        std::remove(HEADER_TMP_FILE);\n        return false;\n    }\n    if (std::rename(HEADER_TMP_FILE, HEADER_FILE) != 0) {\n        if (!path_exists(HEADER_FILE) && path_exists(HEADER_PREV_FILE)) {\n            (void)std::rename(HEADER_PREV_FILE, HEADER_FILE);\n        }\n        std::remove(HEADER_TMP_FILE);\n        return false;\n    }\n    return true;\n}\n'''
if old not in s: raise SystemExit('queue atomic block missing')
s=s.replace(old,new,1)
# include prev as sidecar / cleanup where relevant
s=s.replace('path_exists(HEADER_FILE) || path_exists(HEADER_TMP_FILE) ||\n        path_exists(LEGACY_QUEUE_FILE)', 'path_exists(HEADER_FILE) || path_exists(HEADER_TMP_FILE) ||\n        path_exists(HEADER_PREV_FILE) || path_exists(LEGACY_QUEUE_FILE)',1)
s=s.replace('    std::remove(HEADER_TMP_FILE);\n    std::remove(COMPACT_QUEUE_FILE);','    std::remove(HEADER_TMP_FILE);\n    std::remove(HEADER_PREV_FILE);\n    std::remove(COMPACT_QUEUE_FILE);',1)
s=s.replace('        path_exists(QUEUE_FILE) || path_exists(HEADER_FILE) ||\n        path_exists(HEADER_TMP_FILE) || path_exists(LEGACY_QUEUE_FILE)', '        path_exists(QUEUE_FILE) || path_exists(HEADER_FILE) ||\n        path_exists(HEADER_TMP_FILE) || path_exists(HEADER_PREV_FILE) || path_exists(LEGACY_QUEUE_FILE)',1)
# successful compaction cleanup should discard obsolete previous header after write_header has established new pair
s=s.replace('    std::remove(LEGACY_QUEUE_FILE);\n    std::remove(LEGACY_HEADER_FILE);\n    const uint16_t older_not_scanned', '    std::remove(LEGACY_QUEUE_FILE);\n    std::remove(LEGACY_HEADER_FILE);\n    // HEADER_PREV_FILE now contains at most the prior compacted commit and is\n    // intentionally retained as the crash-recovery predecessor.\n    const uint16_t older_not_scanned',1)
p.write_text(s)

# Y1: preserve failure counters across backoff class changes until success.
p=root/'components/oim_runtime/oim_runtime.cpp'; s=p.read_text()
s=s.replace('''    // A transient failure after a configuration-class problem starts a fresh\n    // short retry sequence. Successful delivery resets both classes separately.\n    if (s_backoff_class != BackoffClass::Transient) s_transient_failures = 0U;\n    s_configuration_failures = 0U;\n\n''','''    // Keep transient/configuration histories independent. Alternating failure\n    // classes must not continuously reset each other's escalation counters.\n    // A verified successful delivery resets both in reset_network_backoff().\n''',1)
s=s.replace('''    // Endpoint/auth/protocol configuration problems are not expected to heal in\n    // a few seconds. Escalate to a battery-friendly 15 min .. 1 h schedule.\n    if (s_backoff_class != BackoffClass::Configuration) s_configuration_failures = 0U;\n    s_transient_failures = 0U;\n\n''','''    // Endpoint/auth/protocol configuration problems are not expected to heal in\n    // a few seconds. Escalate to a battery-friendly 15 min .. 1 h schedule.\n    // Do not erase transient history; the two classes are independent.\n''',1)
p.write_text(s)

# Y2: station minimum auth threshold.
p=root/'components/oim_wifi/oim_wifi.cpp'; s=p.read_text()
needle='''    cfg.sta.scan_method = WIFI_ALL_CHANNEL_SCAN;\n    cfg.sta.sort_method = WIFI_CONNECT_AP_BY_SIGNAL;\n    cfg.sta.pmf_cfg.capable = true;'''
repl='''    cfg.sta.scan_method = WIFI_ALL_CHANNEL_SCAN;\n    cfg.sta.sort_method = WIFI_CONNECT_AP_BY_SIGNAL;\n    // Production station policy: an empty password may join an explicitly open\n    // AP; any protected network must provide WPA2-PSK or stronger. This prevents\n    // accidental downgrade to WEP/WPA1 while remaining compatible with WPA2/3\n    // transition-mode hotspots.\n    cfg.sta.threshold.authmode = password.empty() ? WIFI_AUTH_OPEN : WIFI_AUTH_WPA2_PSK;\n    cfg.sta.pmf_cfg.capable = true;'''
if needle not in s: raise SystemExit('wifi threshold insertion missing')
p.write_text(s.replace(needle,repl,1))

# Y4: compare all bytes, not just first 128.
p=root/'components/oim_config/oim_config.cpp'; s=p.read_text()
old='''bool constant_time_equals(const std::string &a, const std::string &b)\n{\n    constexpr size_t max_len = 128;\n    uint32_t diff = static_cast<uint32_t>(a.size() ^ b.size());\n    for (size_t i = 0; i < max_len; ++i) {\n        const uint8_t av = i < a.size() ? static_cast<uint8_t>(a[i]) : 0;\n        const uint8_t bv = i < b.size() ? static_cast<uint8_t>(b[i]) : 0;\n        diff |= static_cast<uint32_t>(av ^ bv);\n    }\n    return diff == 0;\n}\n'''
new='''bool constant_time_equals(const std::string &a, const std::string &b)\n{\n    // Compare every byte. Runtime depends on public string length, never on the\n    // first mismatching secret byte; tails beyond the old 128-byte ceiling can\n    // no longer be silently ignored.\n    const size_t max_len = std::max(a.size(), b.size());\n    size_t diff = a.size() ^ b.size();\n    for (size_t i = 0; i < max_len; ++i) {\n        const uint8_t av = i < a.size() ? static_cast<uint8_t>(a[i]) : 0U;\n        const uint8_t bv = i < b.size() ? static_cast<uint8_t>(b[i]) : 0U;\n        diff |= static_cast<size_t>(av ^ bv);\n    }\n    return diff == 0U;\n}\n'''
if old not in s: raise SystemExit('constant time block missing')
p.write_text(s.replace(old,new,1))

# N4: 30/120 s discovery, then hard 300/600 s cap from first client, independent of activity.
p=root/'components/oim_provision/oim_provision.cpp'; s=p.read_text()
s=s.replace('''    const uint32_t started_ms = now_ms();\n    const uint32_t no_client_since_ms = started_ms;\n    bool client_seen = false;''','''    const uint32_t started_ms = now_ms();\n    const uint32_t no_client_since_ms = started_ms;\n    uint32_t first_client_ms = 0U;\n    bool client_seen = false;''',1)
s=s.replace('''        if (!client_seen &&\n            (now - started_ms) >= absolute_limit_seconds * 1000UL) {\n            ESP_LOGW(TAG, "Wi-Fi provisioning pre-client session cap reached");\n            break;\n        }\n\n        if (s_client_count.load(std::memory_order_relaxed) > 0U) {\n            if (!client_seen) {\n                client_seen = true;\n                ESP_LOGI(TAG, "Provisioning client acquired; initial no-client timeout cancelled");\n            }''','''        if (client_seen && first_client_ms != 0U &&\n            (now - first_client_ms) >= absolute_limit_seconds * 1000UL) {\n            ESP_LOGW(TAG, "Provisioning hard session cap reached after first client");\n            break;\n        }\n\n        if (s_client_count.load(std::memory_order_relaxed) > 0U) {\n            if (!client_seen) {\n                client_seen = true;\n                first_client_ms = now;\n                ESP_LOGI(TAG, "Provisioning client acquired; initial no-client timeout cancelled; hard session cap armed");\n            }''',1)
s=s.replace('''             "Wi-Fi provisioning policy: no-client=%u s session-cap=%u s client-idle=%u s configured=%s",''','''             "Wi-Fi provisioning policy: no-client=%u s post-client-hard-cap=%u s client-idle=%u s configured=%s",''',1)
p.write_text(s)

# N8: 1 ms ADC inter-sample wait must not become one 10 ms FreeRTOS tick at 100 Hz.
p=root/'components/oim_sensors/oim_sensors.cpp'; s=p.read_text()
s=s.replace('vTaskDelay(pdMS_TO_TICKS(1));','esp_rom_delay_us(1000U);')
p.write_text(s)

# Production Kconfig: safe RTC source, -Os, WARN runtime/bootloader. Keep max INFO for field-debug builds.
p=root/'sdkconfig.defaults'; s=p.read_text()
s=s.replace('V2.1.7 FACTORY QA','V2.1.9 PRODUCTION HARDENING')
s=s.replace('V2.1.7 still uses','V2.1.9 still uses')
s=s.replace('# Deep-sleep wall-clock accuracy: the default ~150 kHz RC oscillator showed\n# roughly +60 s/hour drift in long-run Phase 5 data. 8MD256 needs no external\n# crystal and trades about +5 uA deep-sleep current for substantially better\n# frequency stability.\nCONFIG_RTC_CLK_SRC_INT_8MD256=y\nCONFIG_RTC_CLK_CAL_CYCLES=3000',
'''# Deep-sleep safety: use the ESP32 default internal RC slow clock. 8MD256 has\n# documented ESP32 deep-sleep wake timing/compatibility issues. Cadence feedback\n# and periodic SNTP resync remain responsible for long-term drift correction.\nCONFIG_RTC_CLK_SRC_INT_RC=y\nCONFIG_RTC_CLK_CAL_CYCLES=3000''')
s=s.replace('# V2.1.7 offline ring queue','# V2.1.9 offline ring queue')
# append production build/log settings before end
s += '''\n# Production profile: optimize application for size/active time and suppress INFO\n# UART traffic by default. Maximum INFO remains compiled so engineering builds can\n# raise component levels without changing source.\nCONFIG_COMPILER_OPTIMIZATION_SIZE=y\nCONFIG_LOG_DEFAULT_LEVEL_WARN=y\nCONFIG_LOG_MAXIMUM_LEVEL_INFO=y\nCONFIG_BOOTLOADER_LOG_LEVEL_WARN=y\n'''
p.write_text(s)

# Keep factory machine-readable QA line available at WARN even with production default logs.
p=root/'main/app_main.cpp'; s=p.read_text()
s=s.replace('''    ESP_LOGI(TAG,\n             "VSFACT1 serial=%s hw_id=%s fw=%s schema=%u sensor_init=%s sht45=%s temp_c=%s humidity_pct=%s dew_point_c=%s battery_status=%s battery_v=%s charging=%s",''','''    ESP_LOGW(TAG,\n             "VSFACT1 serial=%s hw_id=%s fw=%s schema=%u sensor_init=%s sht45=%s temp_c=%s humidity_pct=%s dew_point_c=%s battery_status=%s battery_v=%s charging=%s",''',1)
p.write_text(s)

# Docs/version consistency. Keep historical sections but current-release references must be v2.1.9.
p=root/'README.md'; s=p.read_text()
header='''## V2.1.9 — production hardening\n\n- 30 s configured-device power-on provisioning discovery is retained; after a phone connects, a non-resettable 300 s hard cap applies (600 s for unconfigured devices).\n- AES-GCM nonce high-water is dual-persisted in normal NVS + the dedicated `nonce_state` NVS partition at 0x18000; live-send no longer depends on SPIFFS health.\n- Queue backup metadata uses current/previous crash-safe rotation instead of delete-before-rename.\n- RTC slow clock returns to internal RC for ESP32 deep-sleep safety; periodic SNTP/cadence feedback handles drift.\n- Independent transient/configuration backoff histories, STA auth threshold, full-length constant-time secret comparison and deterministic ADC microsecond waits are enabled.\n- Production build defaults to `-Os` and WARN UART logging while preserving the `VSFACT1` factory QA line.\n\n'''
# remove v218 title at top and place current heading
s=re.sub(r'^## V2\.1\.8 — 30 s power-on provisioning\n\n',header,s,count=1)
s=s.replace('# VisionSen ESP-IDF V2.1.8 — FACTORY QA','# VisionSen ESP-IDF V2.1.9 — PRODUCTION HARDENING',1)
s=s.replace('Firmware: `2.1.8`','Firmware: `2.1.9`',1)
s=s.replace('current release: `PROJECT_VER=2.1.7`','current release: `PROJECT_VER=2.1.9`')
p.write_text(s)

# New release summary and update key docs current labels.
(root/'V2.1.9_PRODUCTION_HARDENING_SUMMARY.md').write_text('''# VisionSen OIM3 V2.1.9 — Production Hardening\n\nThis release closes the V2.1.8 release-gate/provisioning regressions and the highest-priority V2.1.7 findings selected for production hardening.\n\n## Runtime contract\n\n- Configured real power-on: SoftAP discovery for 30 seconds.\n- Unconfigured boot: SoftAP discovery for 120 seconds.\n- First phone association cancels the discovery timeout but arms an activity-independent hard cap: 300 s configured / 600 s unconfigured.\n- Deep-sleep wake never opens provisioning.\n- AES-GCM nonce blocks are reserved in two NVS persistence domains: normal `nvs` + dedicated `nonce_state` (0x18000/0x8000). SPIFFS failure does not block live-send nonce allocation.\n- `storage` and `factory_data` remain untouched by application/full-flash payloads.\n- Production defaults: size optimization, WARN logging, internal RC RTC slow clock.\n''')
for rel in ['docs/RUNTIME_VALIDATION.md','FINAL_RELEASE_CHECKLIST.md']:
    p=root/rel; t=p.read_text(); t=t.replace('V2.1.7 FACTORY QA','V2.1.9 PRODUCTION HARDENING'); t=t.replace('V2.1.7 factory','V2.1.9 factory'); t=t.replace('V2.1.7 mandatory','V2.1.9 mandatory'); t=t.replace('V2.1.7 is HTTPS-only','V2.1.9 is HTTPS-only'); p.write_text(t)
p=root/'docs/FACTORY_IDENTITY.md'; t=p.read_text().replace('fw=2.1.7','fw=2.1.9'); p.write_text(t)

# Replace validate_final with v2.1.9-aware release gate + correct Kconfig parser.
validate=r'''#!/usr/bin/env python3
"""Release-gate invariants for VisionSen OIM3 V2.1.9 PRODUCTION HARDENING."""
from __future__ import annotations
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def text(rel: str) -> str: return (ROOT / rel).read_text(encoding="utf-8", errors="replace")
PROJECT_CMAKE=text("CMakeLists.txt"); BOARD=text("components/oim_board/include/oim_board.hpp")
QUEUE=text("components/oim_queue/oim_queue.cpp"); QH=text("components/oim_queue/include/oim_queue.hpp")
CONFIG=text("components/oim_config/oim_config.cpp"); APP=text("main/app_main.cpp")
RUNTIME=text("components/oim_runtime/oim_runtime.cpp"); WIFI=text("components/oim_wifi/oim_wifi.cpp")
PROVISION=text("components/oim_provision/oim_provision.cpp"); SENSORS=text("components/oim_sensors/oim_sensors.cpp")
OIM3=text("components/oim_oim3/oim_oim3.cpp"); OIM3_CMAKE=text("components/oim_oim3/CMakeLists.txt")
NONCE=text("components/oim_nonce/oim_nonce.cpp"); NONCE_CMAKE=text("components/oim_nonce/CMakeLists.txt")
SDK=text("sdkconfig.defaults"); PARTITIONS=text("partitions.csv"); README=text("README.md")
FACTORY=text("components/oim_factory/oim_factory.cpp"); FACTORY_H=text("components/oim_factory/include/oim_factory.hpp")
FACTORY_TOOL=text("tools/factory_serial.py")

def uint_const(name: str) -> int:
    m=re.search(rf"inline constexpr unsigned {re.escape(name)} = (\d+);", BOARD)
    assert m, f"missing board constant {name}"; return int(m.group(1))
def str_const(name: str) -> str:
    m=re.search(rf'inline constexpr const char \*{re.escape(name)} = "([^"]+)";', BOARD)
    assert m, f"missing board string {name}"; return m.group(1)
def sdk_has(blob: str, item: str) -> bool:
    k, sep, v=item.partition("="); assert sep
    return ((item in blob) or (f"# {k} is not set" in blob)) if v == "n" else (item in blob)

assert str_const("FIRMWARE_VERSION") == "2.1.9"
assert str_const("FIRMWARE_NAME") == "VS-ESP-IDF-V2.1.9-OIM3-PRODUCTION"
assert 'set(PROJECT_VER "2.1.9")' in PROJECT_CMAKE
assert "V2.1.9" in README

# Provisioning state machine: 30 s discovery for configured power-on, then a
# hard cap that cannot be refreshed by HTTP polling/activity.
assert uint_const("WIFI_RECONFIG_POWERON_WINDOW_SECONDS") == 30
assert uint_const("WIFI_PROVISION_TIMEOUT_SECONDS") == 120
assert uint_const("WIFI_PROVISION_CONFIGURED_MAX_SESSION_SECONDS") == 300
assert uint_const("WIFI_PROVISION_UNCONFIGURED_MAX_SESSION_SECONDS") == 600
assert 'first_client_ms = now;' in PROVISION
assert 'Provisioning hard session cap reached after first client' in PROVISION
assert '(now - first_client_ms) >= absolute_limit_seconds * 1000UL' in PROVISION
hardpos=PROVISION.index('(now - first_client_ms) >= absolute_limit_seconds * 1000UL')
activitypos=PROVISION.index('s_last_activity_ms.load', hardpos)
assert hardpos < activitypos
assert 'reset_reason == ESP_RST_POWERON' in APP
assert 'WIFI_RECONFIG_POWERON_WINDOW_SECONDS' in APP

# K1: nonce safety is independent of SPIFFS. New mirror lives in unused pre-OTA gap.
assert 'nonce_state, data, nvs,     0x18000,  0x8000,' in PARTITIONS
assert 'nvs_open_from_partition' in NONCE and 'nonce_state' in NONCE
assert 'automatic erase REFUSED' in NONCE
assert 'commit_next(nullptr, next)' in NONCE and 'commit_next(MIRROR_PARTITION, next)' in NONCE
assert 'oim::nonce::reserve_block' in OIM3
assert 'oim_queue.hpp' not in OIM3
assert 'oim_nonce' in OIM3_CMAKE and 'oim_queue' not in OIM3_CMAKE
assert 'load_nonce_high_water' not in QH and 'store_nonce_high_water' not in QH

# K2: do not use ESP32 INT_8MD256 as RTC slow clock for deep sleep.
assert 'CONFIG_RTC_CLK_SRC_INT_RC=y' in SDK
assert 'CONFIG_RTC_CLK_SRC_INT_8MD256=y' not in SDK

# K3: queue commit copy is never delete-before-replace; previous committed header survives.
assert 'HEADER_PREV_FILE' in QUEUE
assert 'fsync(::fileno(f))' in QUEUE
assert 'std::rename(HEADER_FILE, HEADER_PREV_FILE)' in QUEUE
assert 'read_header_file(HEADER_PREV_FILE' in QUEUE
atomic=QUEUE.split('bool write_backup_header_atomic',1)[1].split('bool write_primary_header',1)[0]
assert 'std::remove(HEADER_FILE);' not in atomic

# Y1/Y2/Y4/N8.
transient=RUNTIME.split('void schedule_network_retry',1)[1].split('void schedule_configuration_retry',1)[0]
configretry=RUNTIME.split('void schedule_configuration_retry',1)[1].split('bool should_attempt_network_this_cycle',1)[0]
assert 's_configuration_failures = 0U' not in transient
assert 's_transient_failures = 0U' not in configretry
assert 'cfg.sta.threshold.authmode = password.empty() ? WIFI_AUTH_OPEN : WIFI_AUTH_WPA2_PSK;' in WIFI
cte=CONFIG.split('bool constant_time_equals',1)[1].split('bool is_valid_wifi_credentials',1)[0]
assert 'std::max(a.size(), b.size())' in cte and 'constexpr size_t max_len = 128' not in cte
assert 'vTaskDelay(pdMS_TO_TICKS(1))' not in SENSORS
assert SENSORS.count('esp_rom_delay_us(1000U);') >= 2

# Production build/log policy. n-valued Kconfig checks correctly accept generated '# ... is not set'.
required=(
 'CONFIG_BT_ENABLED=n','CONFIG_ESP_WIFI_SOFTAP_SUPPORT=y','CONFIG_MBEDTLS_CERTIFICATE_BUNDLE=y',
 'CONFIG_MBEDTLS_GCM_C=y','CONFIG_MBEDTLS_SHA256_C=y','CONFIG_RTC_CLK_SRC_INT_RC=y',
 'CONFIG_COMPILER_OPTIMIZATION_SIZE=y','CONFIG_LOG_DEFAULT_LEVEL_WARN=y',
 'CONFIG_BOOTLOADER_LOG_LEVEL_WARN=y')
for item in required: assert sdk_has(SDK,item), f"sdkconfig.defaults missing {item}"
generated=ROOT/'sdkconfig'
if generated.exists():
    g=generated.read_text(encoding='utf-8',errors='replace')
    for item in required: assert sdk_has(g,item), f"generated sdkconfig did not apply {item}"
    assert sdk_has(g,'CONFIG_RTC_CLK_SRC_INT_8MD256=n')
    assert sdk_has(g,'CONFIG_COMPILER_OPTIMIZATION_DEBUG=n')
    generated_state='CHECKED'
else: generated_state='not present (source-only validation)'
assert 'ESP_LOGW(TAG,\n             "VSFACT1 serial=%s' in APP

# Preserve core identity/flash/storage contracts.
assert 'factory_data, data, nvs,     0x12000,  0x6000,' in PARTITIONS
assert 'storage,     data, spiffs,  0x320000, 0x0E0000,' in PARTITIONS
assert 'FACTORY_SCHEMA_VERSION = 2' in FACTORY_H
assert 'MIN_PROVISION_SECRET_BYTES = 8' in FACTORY_H and 'MAX_PROVISION_SECRET_BYTES = 8' in FACTORY_H
assert 'nvs_open_from_partition' in FACTORY and 'NVS_READONLY' in FACTORY
assert 'PROVISION_SECRET_RE = re.compile(r"^[A-Za-z0-9]{8}$")' in FACTORY_TOOL
assert 'nvs_flash_erase' not in APP
assert 'esp_partition_erase_range' not in QUEUE
assert 'automatic format REFUSED' in QUEUE
assert 'destructive reset REFUSED' in QUEUE
assert 'Queue metadata committed to backup' in QUEUE
assert 'previous_header' in QUEUE

# Queue geometry and network timing budget remain bounded.
physical=uint_const('OFFLINE_QUEUE_PHYSICAL_RECORDS'); retention=uint_const('OFFLINE_QUEUE_RETENTION_RECORDS')
sample=uint_const('SENSOR_SAMPLE_INTERVAL_SECONDS'); latest=uint_const('CURRENT_PACKET_LATEST_SEND_START_MS')
http=uint_const('HTTP_TIMEOUT_MS'); tail=uint_const('NETWORK_CYCLE_TAIL_GUARD_MS'); flush=uint_const('OFFLINE_QUEUE_FLUSH_MEASUREMENT_BUDGET_MS')
assert physical == 64 and retention == 60 and retention < physical
assert retention*sample == 3600
assert flush <= latest and latest+http+tail <= sample*1000

# Parse fixed partitions and assert no overlap / exact 4 MiB end.
parts=[]
for raw in PARTITIONS.splitlines():
    line=raw.strip()
    if not line or line.startswith('#'): continue
    cols=[c.strip() for c in line.split(',')]
    if len(cols)<5 or not cols[3] or not cols[4]: continue
    off=int(cols[3],0); size=int(cols[4],0); parts.append((off,off+size,cols[0]))
parts.sort()
for (_,pe,pn),(ns,_,nn) in zip(parts,parts[1:]): assert pe<=ns, f"partition overlap {pn}->{nn}"
assert max(e for _,e,_ in parts)==0x400000
# nonce_state must fit precisely in the old unused 0x18000..0x20000 gap.
nonce_part=[p for p in parts if p[2]=='nonce_state'][0]
assert nonce_part[:2] == (0x18000,0x20000)

# No stale current-release labels.
assert 'PROJECT_VER=2.1.7' not in README
assert 'V2.1.7 FACTORY QA' not in SDK
assert not any(p.name=='__pycache__' for p in ROOT.rglob('__pycache__'))
assert not any(ROOT.rglob('*.pyc'))

print('V2.1.9 PRODUCTION HARDENING invariant validation: PASS')
print(f'queue={retention}/{physical}, sample={sample}s, network_budget={latest}+{http}+{tail}ms')
print('nonce persistence: default NVS + nonce_state NVS (SPIFFS-independent)')
print('provisioning: configured discovery=30s, post-client hard-cap=300s; unconfigured hard-cap=600s')
print('generated sdkconfig: '+generated_state)
'''
(root/'tools/validate_final.py').write_text(validate)

print('patched', root)
