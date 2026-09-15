from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()


def replace_one(rel: str, old: str, new: str) -> None:
    p = root / rel
    s = p.read_text(encoding="utf-8")
    if s.count(old) != 1:
        raise SystemExit(f"{rel}: expected exactly one match, got {s.count(old)}")
    p.write_text(s.replace(old, new, 1), encoding="utf-8")


replace_one(
    "components/oim_runtime/include/oim_runtime.hpp",
    "bool should_attempt_network_this_cycle(uint32_t elapsed_seconds);\n",
    "void advance_network_backoff(uint32_t elapsed_seconds);\n"
    "bool network_attempt_allowed();\n",
)

replace_one(
    "components/oim_runtime/oim_runtime.cpp",
    '''bool should_attempt_network_this_cycle(uint32_t elapsed_seconds)
{
    if (s_network_retry_remaining_s == 0U) return true;
    if (elapsed_seconds == 0U) elapsed_seconds = oim::board::SENSOR_SAMPLE_INTERVAL_SECONDS;
    if (s_network_retry_remaining_s <= elapsed_seconds) {
        s_network_retry_remaining_s = 0U;
        ESP_LOGI(TAG, "%s backoff elapsed; network is no longer blocked (next attempt waits for an upload/recovery window)", backoff_name());
        return true;
    }

    s_network_retry_remaining_s -= elapsed_seconds;
    ESP_LOGI(TAG, "%s backoff active; network remains blocked, ~%lu s remaining",
             backoff_name(), static_cast<unsigned long>(s_network_retry_remaining_s));
    return false;
}
''',
    '''void advance_network_backoff(uint32_t elapsed_seconds)
{
    if (s_network_retry_remaining_s == 0U) return;
    if (elapsed_seconds == 0U) elapsed_seconds = oim::board::SENSOR_SAMPLE_INTERVAL_SECONDS;
    if (s_network_retry_remaining_s <= elapsed_seconds) {
        s_network_retry_remaining_s = 0U;
        ESP_LOGI(TAG, "%s backoff elapsed; network is no longer blocked (next attempt waits for an upload/recovery window)", backoff_name());
        return;
    }

    s_network_retry_remaining_s -= elapsed_seconds;
    ESP_LOGI(TAG, "%s backoff active; network remains blocked, ~%lu s remaining",
             backoff_name(), static_cast<unsigned long>(s_network_retry_remaining_s));
}

bool network_attempt_allowed()
{
    return s_network_retry_remaining_s == 0U;
}
''',
)

replace_one(
    "main/app_main.cpp",
    '''    const bool backoff_allows_network = oim::runtime::should_attempt_network_this_cycle(
        oim::board::SENSOR_SAMPLE_INTERVAL_SECONDS);
''',
    '''    oim::runtime::advance_network_backoff(oim::board::SENSOR_SAMPLE_INTERVAL_SECONDS);
    const bool backoff_allows_network = oim::runtime::network_attempt_allowed();
''',
)

# Existing validator splits the configuration-retry body at the old predicate.
replace_one(
    "tools/validate_final.py",
    "configretry=RUNTIME.split('void schedule_configuration_retry',1)[1].split('bool should_attempt_network_this_cycle',1)[0]\n",
    "configretry=RUNTIME.split('void schedule_configuration_retry',1)[1].split('void advance_network_backoff',1)[0]\n",
)

p = root / "tools/validate_final.py"
s = p.read_text(encoding="utf-8")
marker = "print('V2.1.9 PRODUCTION HARDENING invariant validation: PASS')\n"
checks = '''# Y3: query predicates must not mutate retry state. Backoff time is advanced
# exactly once by an explicit state-transition function before the pure query.
assert 'should_attempt_network_this_cycle' not in RUNTIME
assert 'void advance_network_backoff(uint32_t elapsed_seconds)' in RUNTIME
assert 'bool network_attempt_allowed()' in RUNTIME
assert 's_network_retry_remaining_s -=' in RUNTIME.split('void advance_network_backoff',1)[1].split('bool network_attempt_allowed',1)[0]
allowed_body=RUNTIME.split('bool network_attempt_allowed()',1)[1].split('void reset_network_backoff',1)[0]
assert 's_network_retry_remaining_s =' not in allowed_body
assert 'advance_network_backoff(oim::board::SENSOR_SAMPLE_INTERVAL_SECONDS);' in APP
assert 'const bool backoff_allows_network = oim::runtime::network_attempt_allowed();' in APP

'''
if marker not in s:
    raise SystemExit("validator success marker missing")
s = s.replace(marker, checks + marker, 1)
p.write_text(s, encoding="utf-8")

# Release notes: explicitly close Y3.
p = root / "README.md"
s = p.read_text(encoding="utf-8")
needle = "- Backoff failure classes retain independent escalation histories.\n"
if needle in s and "side-effect-free" not in s:
    s = s.replace(
        needle,
        needle + "- Backoff elapsed-time advancement is explicit; the network-allowed predicate is side-effect-free.\n",
        1,
    )
p.write_text(s, encoding="utf-8")

print("V2.1.9 Y3 side-effect predicate hardening applied")
