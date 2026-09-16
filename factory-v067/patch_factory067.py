from pathlib import Path
p=Path('factory_pc_tool_v067/visionsen_factory_tool.py')
s=p.read_text(encoding='utf-8')

def rep(old,new):
    global s
    if old not in s:
        raise SystemExit('Factory 0.6.7 transform anchor missing: '+old[:140])
    s=s.replace(old,new,1)

rep('APP_VERSION = "0.6.6"', 'APP_VERSION = "0.6.7"')
rep('''        conn.columnconfigure(1, weight=1)
        lbl(conn, "COM Port").grid(row=0, column=0, sticky="w", padx=(2, 8), pady=3)
        self.port_var = tk.StringVar()
        self.port_combo = ttk.Combobox(conn, textvariable=self.port_var, width=34, state="readonly", style="VS.TCombobox")
        self.port_combo.grid(row=0, column=1, sticky="ew", padx=(0, 8), pady=3)
        self.refresh_button = btn(conn, "Yenile", self.refresh_ports, width=10)
        self.refresh_button.grid(row=0, column=2, padx=4, pady=3)
        self.connect_button = btn(conn, "Bağlan", self.connect_com, width=10)
        self.connect_button.grid(row=0, column=3, padx=4, pady=3)
        self.disconnect_button = btn(conn, "Bağlantıyı Kes", self.disconnect_com, width=13, state="disabled")
        self.disconnect_button.grid(row=0, column=4, padx=4, pady=3)
        self.com_status_var = tk.StringVar(value="COM: bağlı değil")
        tk.Label(conn, textvariable=self.com_status_var, bg=PANEL, fg=MUTED,
                 font=("Segoe UI", 9, "bold")).grid(row=0, column=5, sticky="w", padx=(12, 2))

        # Bağlantı ve uzun süren tüm kart işlemleri için ortak ilerleme alanı.
        self.progress_value = tk.DoubleVar(value=0.0)
        self.progress_text_var = tk.StringVar(value="0%")
        self._progress_job = None
        self.operation_progress = ttk.Progressbar(conn, mode="determinate", maximum=100, variable=self.progress_value, style="VS.Horizontal.TProgressbar")
        self.operation_progress.grid(row=1, column=0, columnspan=5, sticky="ew", padx=(2, 8), pady=(7, 2))
        tk.Label(conn, textvariable=self.progress_text_var, bg=PANEL, fg=MUTED, font=("Segoe UI", 8, "bold"), width=5).grid(row=1, column=5, sticky="e", padx=(4, 2), pady=(7, 2))
''','''        conn.columnconfigure(1, weight=1)
        lbl(conn, "COM Port").grid(row=0, column=0, sticky="w", padx=(2, 8), pady=3)
        self.port_var = tk.StringVar()
        self.port_combo = ttk.Combobox(conn, textvariable=self.port_var, width=34, state="readonly", style="VS.TCombobox")
        self.port_combo.grid(row=0, column=1, sticky="ew", padx=(0, 8), pady=3)
        self.refresh_button = btn(conn, "Yenile", self.refresh_ports, width=10)
        self.refresh_button.grid(row=0, column=2, padx=4, pady=3)
        self.connect_button = btn(conn, "Bağlan", self.connect_com, width=10)
        self.connect_button.grid(row=0, column=3, padx=4, pady=3)
        self.disconnect_button = btn(conn, "Bağlantıyı Kes", self.disconnect_com, width=13, state="disabled")
        self.disconnect_button.grid(row=0, column=4, padx=4, pady=3)

        # Progress ayrı satır/frame: yüzde ve durum metni COM butonlarının alanına giremez.
        self.progress_value = tk.DoubleVar(value=0.0)
        self.progress_text_var = tk.StringVar(value="0%")
        self._progress_job = None
        progress_row = tk.Frame(conn, bg=PANEL)
        progress_row.grid(row=1, column=0, columnspan=5, sticky="ew", padx=2, pady=(7, 2))
        progress_row.columnconfigure(0, weight=1)
        self.operation_progress = ttk.Progressbar(progress_row, mode="determinate", maximum=100, variable=self.progress_value, style="VS.Horizontal.TProgressbar")
        self.operation_progress.grid(row=0, column=0, sticky="ew", padx=(0, 8))
        tk.Label(progress_row, textvariable=self.progress_text_var, bg=PANEL, fg=MUTED, font=("Segoe UI", 8, "bold"), width=5, anchor="e").grid(row=0, column=1, sticky="e")

        self.com_status_var = tk.StringVar(value="COM: bağlı değil")
        tk.Label(conn, textvariable=self.com_status_var, bg=PANEL, fg=MUTED,
                 font=("Segoe UI", 9, "bold"), anchor="w").grid(row=2, column=0, columnspan=5, sticky="ew", padx=2, pady=(2, 1))
''')
rep('''    def _service_hardware_changed(self) -> bool:
        if not self._loaded_identity_serial:
            return False
        selected = self._selected_manifest_sensor_keys(allow_empty=True)
        if not selected:
            return bool(self._loaded_manifest_sensors)
        return normalize_manifest_sensor_keys(selected) != normalize_manifest_sensor_keys(self._loaded_manifest_sensors)

    def _refresh_service_manifest_summary(self) -> None:
        if not hasattr(self, "service_manifest_summary_var"):
            return
        if not self._loaded_identity_serial:
            self.service_manifest_summary_var.set("Cihaz okunduktan sonra mevcut/yeni donanım karşılaştırması burada gösterilir.")
            return
        old = sensor_models_text(self._loaded_manifest_sensors) if self._loaded_manifest_sensors else "—"
        selected = self._selected_manifest_sensor_keys(allow_empty=True)
        new = sensor_models_text(selected) if selected else "Seçim bekleniyor"
        if self._service_hardware_changed():
''','''    def _service_hardware_changed(self) -> bool:
        if getattr(self, "_manifest_ui_syncing", False) or not self._loaded_identity_serial:
            return False
        selected = self._selected_manifest_sensor_keys(allow_empty=True)
        # Auto-read sırasında checkbox'lar kısa süre boş olabilir. Bu ara durum değişiklik sayılmaz.
        if not selected:
            return False
        loaded = tuple(k for k in (self._loaded_manifest_sensors or ()) if k in SUPPORTED_MANIFEST_SENSOR_KEYS)
        if not loaded:
            return False
        return tuple(sorted(selected)) != tuple(sorted(loaded))

    def _refresh_service_manifest_summary(self) -> None:
        if not hasattr(self, "service_manifest_summary_var"):
            return
        if getattr(self, "_manifest_ui_syncing", False):
            self.service_manifest_summary_var.set("Cihaz donanım bilgisi okunuyor...")
            return
        if not self._loaded_identity_serial:
            self.service_manifest_summary_var.set("Cihaz okunduktan sonra mevcut/yeni donanım karşılaştırması burada gösterilir.")
            return
        old = sensor_models_text(self._loaded_manifest_sensors) if self._loaded_manifest_sensors else "—"
        selected = self._selected_manifest_sensor_keys(allow_empty=True)
        if not selected:
            self.service_manifest_summary_var.set(f"Mevcut: {old}  • Fiziksel sensör seçimi bekleniyor")
            return
        new = sensor_models_text(selected)
        if self._service_hardware_changed():
''')
p.write_text(s,encoding='utf-8',newline='\n')
