from pathlib import Path
p=Path('factory_pc_tool_v065/visionsen_factory_tool.py')
s=p.read_text(encoding='utf-8')

def replace(old,new,count=1):
    global s
    if old not in s:
        raise SystemExit(f'anchor missing: {old[:100]!r}')
    s=s.replace(old,new,count)

replace('SUPPORTED_MANIFEST_SENSOR_KEYS = ("SHT45:1", "BATTERY:1")\n_PROTOCOL_CONTRACT_CACHE: dict[str, object] | None = None\n', '''SUPPORTED_MANIFEST_SENSOR_KEYS = ("SHT45:1", "BATTERY:1")
PHYSICAL_SENSOR_CATALOG = {
    "SHT45:1": {
        "model": "SHT45",
        "measurements": ("Sıcaklık", "Nem", "Çiğ Noktası"),
        "supported": True,
    },
    "BATTERY:1": {
        "model": "Battery ADC",
        "measurements": ("Batarya Gerilimi",),
        "supported": True,
    },
    # Gelecek donanım için UI/catalog hazırlığı. Firmware 2.2.1 henüz PT1000 sürücüsü içermiyor,
    # bu yüzden manifestte seçilebilir değildir ve yanlış üretim kaydı oluşturamaz.
    "PT1000:1": {
        "model": "PT1000",
        "measurements": ("Sıcaklık",),
        "supported": False,
    },
}
_PROTOCOL_CONTRACT_CACHE: dict[str, object] | None = None
''')
replace('def manifest_hash(serial_no: str, version: int, sensor_keys) -> str:\n', '''def sensor_display_text(sensor_key: str) -> str:
    key = str(sensor_key or "").strip().upper()
    item = PHYSICAL_SENSOR_CATALOG.get(key)
    if not item:
        return key or "—"
    measurements = " • ".join(item["measurements"])
    return f"{item['model']} — {measurements}" if measurements else str(item["model"])


def sensor_models_text(sensor_keys) -> str:
    parts = []
    for key in normalize_manifest_sensor_keys(sensor_keys):
        item = PHYSICAL_SENSOR_CATALOG.get(key)
        parts.append(str(item["model"]) if item else key)
    return ", ".join(parts) or "—"


def manifest_hash(serial_no: str, version: int, sensor_keys) -> str:
''')
replace('self.manifest_battery_var = tk.BooleanVar(value=True)','self.manifest_battery_var = tk.BooleanVar(value=False)')
replace('''        self.manifest_sht45_check = self._register_device_widget(tk.Checkbutton(manifest, text="Sıcaklık / Nem / Çiğ Noktası", variable=self.manifest_sht45_var, state="disabled", bg=PANEL, fg=FG, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 9)))
        self.manifest_sht45_check.grid(row=0, column=0, sticky="w", padx=4)
        self.manifest_battery_check = self._register_device_widget(tk.Checkbutton(manifest, text="Battery ADC", variable=self.manifest_battery_var, state="disabled", bg=PANEL, fg=FG, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 9)))
        self.manifest_battery_check.grid(row=0, column=1, sticky="w", padx=4)
''', '''        sht_box = tk.Frame(manifest, bg=PANEL)
        sht_box.grid(row=0, column=0, sticky="w", padx=4)
        self.manifest_sht45_check = self._register_device_widget(tk.Checkbutton(sht_box, text="SHT45", variable=self.manifest_sht45_var, state="disabled", bg=PANEL, fg=FG, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 9, "bold")))
        self.manifest_sht45_check.pack(anchor="w")
        tk.Label(sht_box, text="Sıcaklık • Nem • Çiğ Noktası", bg=PANEL, fg=MUTED, font=("Segoe UI", 8)).pack(anchor="w", padx=(22, 0))

        battery_box = tk.Frame(manifest, bg=PANEL)
        battery_box.grid(row=0, column=1, sticky="w", padx=4)
        self.manifest_battery_check = self._register_device_widget(tk.Checkbutton(battery_box, text="Battery ADC", variable=self.manifest_battery_var, state="disabled", bg=PANEL, fg=FG, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 9, "bold")))
        self.manifest_battery_check.pack(anchor="w")
        tk.Label(battery_box, text="Batarya Gerilimi", bg=PANEL, fg=MUTED, font=("Segoe UI", 8)).pack(anchor="w", padx=(22, 0))

        pt_box = tk.Frame(manifest, bg=PANEL)
        pt_box.grid(row=0, column=2, sticky="w", padx=4)
        self.manifest_pt1000_var = tk.BooleanVar(value=False)
        self.manifest_pt1000_check = tk.Checkbutton(pt_box, text="PT1000", variable=self.manifest_pt1000_var, state="disabled", bg=PANEL, fg=MUTED, disabledforeground=MUTED, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 9, "bold"))
        self.manifest_pt1000_check.pack(anchor="w")
        tk.Label(pt_box, text="Sıcaklık • firmware desteği bekleniyor", bg=PANEL, fg=MUTED, font=("Segoe UI", 8)).pack(anchor="w", padx=(22, 0))
''')
replace('lbl(manifest, "Donanım Revizyonu").grid(row=0, column=2, sticky="e", padx=(20, 4))','lbl(manifest, "Donanım Revizyonu").grid(row=0, column=3, sticky="e", padx=(20, 4))')
replace('self.manifest_version_entry.grid(row=0, column=3, sticky="w")','self.manifest_version_entry.grid(row=0, column=4, sticky="w")')
replace('self.manifest_bump_button.grid(row=0, column=4, padx=6)','self.manifest_bump_button.grid(row=0, column=5, padx=6)')
replace('columnspan=5, sticky="ew", padx=2, pady=(6, 1))','columnspan=6, sticky="ew", padx=2, pady=(6, 1))')
replace('columnspan=5, sticky="ew", padx=2, pady=(2, 1))','columnspan=6, sticky="ew", padx=2, pady=(2, 1))')
replace('self.clear_storage_check.grid(row=0, column=5, sticky="e", padx=6)','self.clear_storage_check.grid(row=1, column=6, sticky="e", padx=6)')
replace('''        self.service_sht45_check = self._register_device_widget(tk.Checkbutton(shw, text="Sıcaklık / Nem / Çiğ Noktası", variable=self.manifest_sht45_var, state="disabled", bg=PANEL, fg=FG, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 9)))
        self.service_sht45_check.grid(row=0, column=0, sticky="w", padx=4)
        self.service_battery_check = self._register_device_widget(tk.Checkbutton(shw, text="Battery ADC", variable=self.manifest_battery_var, state="disabled", bg=PANEL, fg=FG, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 9)))
        self.service_battery_check.grid(row=0, column=1, sticky="w", padx=4)
''', '''        service_sht_box = tk.Frame(shw, bg=PANEL)
        service_sht_box.grid(row=0, column=0, sticky="w", padx=4)
        self.service_sht45_check = self._register_device_widget(tk.Checkbutton(service_sht_box, text="SHT45", variable=self.manifest_sht45_var, state="disabled", bg=PANEL, fg=FG, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 9, "bold")))
        self.service_sht45_check.pack(anchor="w")
        tk.Label(service_sht_box, text="Sıcaklık • Nem • Çiğ Noktası", bg=PANEL, fg=MUTED, font=("Segoe UI", 8)).pack(anchor="w", padx=(22, 0))

        service_battery_box = tk.Frame(shw, bg=PANEL)
        service_battery_box.grid(row=0, column=1, sticky="w", padx=4)
        self.service_battery_check = self._register_device_widget(tk.Checkbutton(service_battery_box, text="Battery ADC", variable=self.manifest_battery_var, state="disabled", bg=PANEL, fg=FG, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 9, "bold")))
        self.service_battery_check.pack(anchor="w")
        tk.Label(service_battery_box, text="Batarya Gerilimi", bg=PANEL, fg=MUTED, font=("Segoe UI", 8)).pack(anchor="w", padx=(22, 0))

        service_pt_box = tk.Frame(shw, bg=PANEL)
        service_pt_box.grid(row=0, column=2, sticky="w", padx=4)
        self.service_pt1000_check = tk.Checkbutton(service_pt_box, text="PT1000", variable=self.manifest_pt1000_var, state="disabled", bg=PANEL, fg=MUTED, disabledforeground=MUTED, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 9, "bold"))
        self.service_pt1000_check.pack(anchor="w")
        tk.Label(service_pt_box, text="Sıcaklık • firmware desteği bekleniyor", bg=PANEL, fg=MUTED, font=("Segoe UI", 8)).pack(anchor="w", padx=(22, 0))
''')
replace('self.service_write_button.grid(row=0, column=3, padx=4)','self.service_write_button.grid(row=0, column=4, padx=4)')
replace('self.service_clear_storage_check.grid(row=0, column=2, padx=8)','self.service_clear_storage_check.grid(row=0, column=3, padx=8)')
replace('tk.Label(shw, textvariable=self.service_manifest_summary_var, bg=PANEL, fg=BLUE, font=("Segoe UI", 9, "bold"), anchor="w").grid(row=1, column=0, columnspan=4, sticky="ew", padx=4, pady=(6, 2))','tk.Label(shw, textvariable=self.service_manifest_summary_var, bg=PANEL, fg=BLUE, font=("Segoe UI", 9, "bold"), anchor="w").grid(row=1, column=0, columnspan=5, sticky="ew", padx=4, pady=(6, 2))')
replace('old = ", ".join(self._loaded_manifest_sensors) or "—"\n        new = ", ".join(self._selected_manifest_sensor_keys()) or "—"','old = sensor_models_text(self._loaded_manifest_sensors) if self._loaded_manifest_sensors else "—"\n        new = sensor_models_text(self._selected_manifest_sensor_keys())')
replace('self.manifest_status_var.set(f"Cihaz manifesti okundu • v{r.manifest_version} • {\',\'.join(r.manifest_sensors)}")','self.manifest_status_var.set(f"Cihaz manifesti okundu • v{r.manifest_version} • {sensor_models_text(r.manifest_sensors)}")')
replace('''            sensors = ",".join(selected)
            self.manifest_hash_var.set(f"Hash: {digest}   •   sensors={sensors}")
''','''            sensors = sensor_models_text(selected)
            self.manifest_hash_var.set(f"Hash: {digest}   •   Fiziksel sensörler: {sensors}")
''')
replace('f"{serial_no} Factory Identity + Device Manifest yazılsın/güncellensin mi?\\n\\nSensörler: {\', \'.join(sensor_keys)}\\nManifest v{manifest_version}\\nHash: {manifest_hash_hex[:16]}…\\nStorage/queue: {storage_note}"','f"{serial_no} Factory Identity + Device Manifest yazılsın/güncellensin mi?\\n\\nFiziksel sensörler: {sensor_models_text(sensor_keys)}\\nManifest v{manifest_version}\\nHash: {manifest_hash_hex[:16]}…\\nStorage/queue: {storage_note}"')
replace('self.test_labels["Çiy"].set((r.dew_point + " °C") if r.dew_point else "—")','self.test_labels["Çiğ Noktası"].set((r.dew_point + " °C") if r.dew_point else "—")')
replace('self.manifest_battery_var.set(True)\n                self.manifest_status_var.set("Factory Device Manifest yok/geçersiz • cihaz üretime alınamaz; manifest yazılmalı.")','self.manifest_battery_var.set(False)\n                self.manifest_status_var.set("Factory Device Manifest yok/geçersiz • cihaz üretime alınamaz; manifest yazılmalı.")')
replace('self.manifest_battery_var.set(True)\n            self.manifest_status_var.set("Yeni cihaz • Sıcaklık / Nem / Çiğ Noktası + Batarya varsayılan seçildi; üretim kartına göre değiştirin.")','self.manifest_battery_var.set(False)\n            self.manifest_status_var.set("Yeni cihaz • SHT45 varsayılan seçildi; fiziksel kart üzerindeki sensör modeline göre değiştirin.")')
p.write_text(s,encoding='utf-8',newline='\n')
