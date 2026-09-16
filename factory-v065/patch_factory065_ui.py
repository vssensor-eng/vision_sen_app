from pathlib import Path
p=Path('factory_pc_tool_v065/visionsen_factory_tool.py')
s=p.read_text(encoding='utf-8')
s=s.replace('APP_VERSION = "0.6.4"','APP_VERSION = "0.6.5"',1)
# init workflow state
old='''        self._loaded_manifest_sensors: tuple[str, ...] = ()\n        self._manifest_ui_syncing = False\n        self._build_ui()\n'''
new='''        self._loaded_manifest_sensors: tuple[str, ...] = ()\n        self._manifest_ui_syncing = False\n        self._workflow_state = {\n            "production_firmware": False,\n            "production_written": False,\n            "production_test": False,\n            "service_read": False,\n            "service_written": False,\n            "service_test": False,\n        }\n        self._active_workflow_event = None\n        self._build_ui()\n'''
if old not in s: raise SystemExit('init anchor missing')
s=s.replace(old,new,1)

start=s.index('    def _build_ui(self):')
end=s.index('    def _set_global_status', start)
new_build=r'''    def _build_ui(self):
        BG = "#111a2c"
        PANEL = "#111a2c"
        FG = "#ffffff"
        MUTED = "#c9d4e7"
        BORDER = "#d7dbe3"
        BLUE = "#7db7ff"
        GREEN = "#54d68a"
        RED = "#ff6b6b"
        AMBER = "#ffd166"
        BUTTON_BG = "#e9e9e9"
        BUTTON_FG = "#000000"
        ENTRY_BG = "#f1f1ee"
        self._ui_colors = {"bg": BG, "fg": FG, "muted": MUTED, "blue": BLUE, "green": GREEN, "red": RED, "amber": AMBER}

        self.configure(bg=BG)
        self.title(f"VisionSen Üretim ve Kalite Kontrol v{APP_VERSION}")
        self.geometry("1180x930")
        self.minsize(1080, 800)

        style = ttk.Style(self)
        try:
            if "clam" in style.theme_names():
                style.theme_use("clam")
        except Exception:
            pass
        style.configure("VS.Horizontal.TProgressbar", troughcolor="#26324a", background=GREEN, bordercolor="#26324a", lightcolor=GREEN, darkcolor=GREEN)
        style.configure("VS.TCombobox", fieldbackground=ENTRY_BG, background=ENTRY_BG, foreground="#000000", arrowcolor="#000000")
        style.configure("VS.TNotebook", background=BG, borderwidth=0)
        style.configure("VS.TNotebook.Tab", padding=(22, 9), font=("Segoe UI", 10, "bold"))

        def btn(parent, text, command, *, width=None, state="normal"):
            w = tk.Button(parent, text=text, command=command, state=state, bg=BUTTON_BG, fg=BUTTON_FG,
                          activebackground="#ffffff", activeforeground="#000000", relief="raised", bd=1,
                          padx=10, pady=4, font=("Segoe UI", 9, "bold"), cursor="hand2")
            if width:
                w.configure(width=width)
            return w

        def lbl(parent, text="", **kw):
            return tk.Label(parent, text=text, bg=PANEL, fg=FG, font=("Segoe UI", 9), **kw)

        def section(parent, text):
            box = tk.LabelFrame(parent, text=text, bg=PANEL, fg=FG, bd=1, relief="groove",
                                highlightbackground=BORDER, padx=10, pady=8,
                                font=("Segoe UI", 9, "bold"))
            return box

        root = tk.Frame(self, bg=BG, padx=14, pady=10)
        root.pack(fill="both", expand=True)
        root.columnconfigure(0, weight=1)
        root.rowconfigure(3, weight=1)

        header = tk.Frame(root, bg=BG)
        header.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        header.columnconfigure(1, weight=1)
        tk.Label(header, text="VisionSen", bg=BG, fg=FG,
                 font=("Segoe UI", 21, "bold")).grid(row=0, column=0, sticky="w")
        self.global_status = tk.Label(header, text="Hazır", bg=BG, fg=BLUE,
                                      font=("Segoe UI", 10, "bold"))
        self.global_status.grid(row=0, column=1, sticky="w", padx=(18, 0))
        self.port_count_var = tk.StringVar(value="COM portları taranıyor")
        tk.Label(header, textvariable=self.port_count_var, bg=BG, fg=BLUE,
                 font=("Segoe UI", 9, "bold")).grid(row=0, column=2, sticky="e")

        # Ortak bağlantı alanı: kullanıcının özellikle istediği dört kontrol korunur.
        conn = section(root, "Cihaz Bağlantısı")
        conn.grid(row=1, column=0, sticky="ew", pady=(0, 8))
        conn.columnconfigure(1, weight=1)
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

        self.workflow_tabs = ttk.Notebook(root, style="VS.TNotebook")
        self.workflow_tabs.grid(row=2, column=0, sticky="nsew")
        prod = tk.Frame(self.workflow_tabs, bg=BG, padx=4, pady=6)
        service = tk.Frame(self.workflow_tabs, bg=BG, padx=4, pady=6)
        self.workflow_tabs.add(prod, text="ÜRETİM")
        self.workflow_tabs.add(service, text="SERVİS")
        self.workflow_tabs.bind("<<NotebookTabChanged>>", lambda _e: self._refresh_workflow_controls())
        for tab in (prod, service):
            tab.columnconfigure(0, weight=1)

        # Paylaşılan alan değişkenleri
        self.firmware_path_var = tk.StringVar(value=f"Gömülü paket • OIM3 v{self.selected_firmware_meta.get('version', REQUIRED_FIRMWARE_VERSION)}")
        self.firmware_info_var = tk.StringVar(value=f"Onaylı üretim firmware'i • OIM3 v{self.selected_firmware_meta.get('version', REQUIRED_FIRMWARE_VERSION)} • factory_data + nonce_state + storage korunur")
        self.firmware_status_var = tk.StringVar(value="Bağlantı bekleniyor.")
        self.identity_status_var = tk.StringVar(value="Bağlantı bekleniyor.")
        self.test_status_var = tk.StringVar(value="Henüz test yapılmadı.")
        self.serial_var = tk.StringVar(value="")
        self.hwrev_var = tk.StringVar(value="OIM3-R1")
        self.prod_var = tk.StringVar(value=date.today().isoformat())
        self.prov_secret_var = tk.StringVar(value=self.generate_secret())
        self.identity_view = tk.StringVar(value="Cihaz kimliği henüz okunmadı")
        self.clear_storage_var = tk.BooleanVar(value=True)
        self.manifest_sht45_var = tk.BooleanVar(value=True)
        self.manifest_battery_var = tk.BooleanVar(value=True)
        self.manifest_version_var = tk.StringVar(value="1")
        self.manifest_hash_var = tk.StringVar(value="Seri no + sensör seçimi ile hesaplanacak")
        self.manifest_status_var = tk.StringVar(value="Yeni cihaz için fiziksel donanımı seçin.")
        self.manifest_help_var = tk.StringVar(value="Sensör seti servis sırasında değişirse donanım revizyonu otomatik artırılır.")
        self.progress_value = tk.DoubleVar(value=0.0)
        self.progress_text_var = tk.StringVar(value="0%")
        self._progress_job = None

        # -------- ÜRETİM --------
        fw = section(prod, "1. Firmware")
        fw.grid(row=0, column=0, sticky="ew", pady=4)
        fw.columnconfigure(1, weight=1)
        lbl(fw, "Firmware").grid(row=0, column=0, sticky="w", padx=(2, 8), pady=3)
        self.firmware_path_entry = tk.Entry(fw, textvariable=self.firmware_path_var, state="readonly",
                                            readonlybackground=ENTRY_BG, fg="#000000", relief="sunken", bd=1)
        self.firmware_path_entry.grid(row=0, column=1, sticky="ew", padx=(0, 8), pady=3)
        self.select_firmware_button = self._register_device_widget(btn(fw, "Harici Firmware Seç", self.select_firmware_file, width=16, state="disabled"))
        self.select_firmware_button.grid(row=0, column=2, padx=4)
        self.embedded_firmware_button = self._register_device_widget(btn(fw, "Gömülü Kullan", self.use_embedded_firmware, width=12, state="disabled"))
        self.embedded_firmware_button.grid(row=0, column=3, padx=4)
        self.flash_button = self._register_device_widget(btn(fw, "Firmware Yükle", self.flash_firmware, width=14, state="disabled"))
        self.flash_button.grid(row=0, column=4, padx=4)
        tk.Label(fw, textvariable=self.firmware_info_var, bg=PANEL, fg=MUTED, font=("Segoe UI", 8)).grid(row=1, column=0, columnspan=3, sticky="w", padx=2, pady=(5, 2))
        self.firmware_status_label = tk.Label(fw, textvariable=self.firmware_status_var, bg=PANEL, fg=MUTED, font=("Segoe UI", 9, "bold"), anchor="w")
        self.firmware_status_label.grid(row=1, column=3, columnspan=2, sticky="ew", padx=6)
        self._operation_status_labels["firmware"] = self.firmware_status_label
        self.operation_progress = ttk.Progressbar(fw, mode="determinate", maximum=100, variable=self.progress_value, style="VS.Horizontal.TProgressbar")
        self.operation_progress.grid(row=2, column=0, columnspan=4, sticky="ew", padx=2, pady=(6, 0))
        tk.Label(fw, textvariable=self.progress_text_var, bg=PANEL, fg=MUTED, font=("Segoe UI", 8, "bold"), width=5).grid(row=2, column=4, sticky="e")

        ident = section(prod, "2. Cihaz Kimliği")
        ident.grid(row=1, column=0, sticky="ew", pady=4)
        for c in (1, 3, 5): ident.columnconfigure(c, weight=1)
        lbl(ident, "Seri No").grid(row=0, column=0, sticky="w", padx=(2, 6), pady=3)
        self.serial_entry = self._register_identity_input(tk.Entry(ident, textvariable=self.serial_var, bg=ENTRY_BG, fg="#000000", state="disabled"))
        self.serial_entry.grid(row=0, column=1, sticky="ew", padx=(0, 8), pady=3)
        lbl(ident, "HW Rev").grid(row=0, column=2, sticky="w", padx=(2, 6), pady=3)
        self.hwrev_entry = self._register_identity_input(tk.Entry(ident, textvariable=self.hwrev_var, bg=ENTRY_BG, fg="#000000", state="disabled"))
        self.hwrev_entry.grid(row=0, column=3, sticky="ew", padx=(0, 8), pady=3)
        lbl(ident, "Üretim Tarihi").grid(row=0, column=4, sticky="w", padx=(2, 6), pady=3)
        self.prod_entry = self._register_identity_input(tk.Entry(ident, textvariable=self.prod_var, bg=ENTRY_BG, fg="#000000", state="disabled"))
        self.prod_entry.grid(row=0, column=5, sticky="ew", padx=(0, 8), pady=3)
        lbl(ident, "Kurulum Kodu").grid(row=1, column=0, sticky="w", padx=(2, 6), pady=3)
        self.secret_entry = self._register_identity_input(tk.Entry(ident, textvariable=self.prov_secret_var, bg=ENTRY_BG, fg="#000000", state="disabled"))
        self.secret_entry.grid(row=1, column=1, sticky="ew", padx=(0, 8), pady=3)
        self.new_secret_button = self._register_device_widget(btn(ident, "Yeni Kod", lambda: self.prov_secret_var.set(self.generate_secret()), width=10, state="disabled"))
        self.new_secret_button.grid(row=1, column=2, padx=4)
        self.copy_secret_button = self._register_device_widget(btn(ident, "Kopyala", self.copy_secret, width=9, state="disabled"))
        self.copy_secret_button.grid(row=1, column=3, padx=4)
        self.write_identity_button = self._register_device_widget(btn(ident, "Kimlik + Donanım Yaz", self.write_identity, width=20, state="disabled"))
        self.write_identity_button.grid(row=1, column=5, sticky="e", padx=4)
        self.read_button = self._register_device_widget(btn(ident, "Cihazdan Oku", self.read_device, width=12, state="disabled"))
        self.read_button.grid(row=1, column=4, sticky="e", padx=4)
        self.identity_status_label = tk.Label(ident, textvariable=self.identity_status_var, bg=PANEL, fg=MUTED, font=("Segoe UI", 9, "bold"), anchor="w")
        self.identity_status_label.grid(row=2, column=0, columnspan=6, sticky="ew", padx=2, pady=(5, 0))
        self._operation_status_labels["identity"] = self.identity_status_label

        manifest = section(prod, "3. Fiziksel Donanım")
        manifest.grid(row=2, column=0, sticky="ew", pady=4)
        self.manifest_sht45_check = self._register_device_widget(tk.Checkbutton(manifest, text="Sıcaklık / Nem / Çiğ Noktası", variable=self.manifest_sht45_var, state="disabled", bg=PANEL, fg=FG, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 9)))
        self.manifest_sht45_check.grid(row=0, column=0, sticky="w", padx=4)
        self.manifest_battery_check = self._register_device_widget(tk.Checkbutton(manifest, text="Battery ADC", variable=self.manifest_battery_var, state="disabled", bg=PANEL, fg=FG, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 9)))
        self.manifest_battery_check.grid(row=0, column=1, sticky="w", padx=4)
        lbl(manifest, "Donanım Revizyonu").grid(row=0, column=2, sticky="e", padx=(20, 4))
        self.manifest_version_entry = self._register_identity_input(tk.Entry(manifest, textvariable=self.manifest_version_var, width=7, bg=ENTRY_BG, fg="#000000", state="disabled"))
        self.manifest_version_entry.grid(row=0, column=3, sticky="w")
        self.manifest_bump_button = self._register_device_widget(btn(manifest, "Sürüm +1", self.bump_manifest_version, width=9, state="disabled"))
        self.manifest_bump_button.grid(row=0, column=4, padx=6)
        tk.Label(manifest, textvariable=self.manifest_status_var, bg=PANEL, fg=BLUE, font=("Segoe UI", 8, "bold"), anchor="w").grid(row=1, column=0, columnspan=5, sticky="ew", padx=2, pady=(6, 1))
        tk.Label(manifest, textvariable=self.manifest_hash_var, bg=PANEL, fg=MUTED, font=("Consolas", 8), anchor="w").grid(row=2, column=0, columnspan=5, sticky="ew", padx=2, pady=(2, 1))
        self.clear_storage_check = self._register_device_widget(tk.Checkbutton(manifest, text="Yeni kimlikte storage/queue temizle", variable=self.clear_storage_var, state="disabled", bg=PANEL, fg=FG, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 8)))
        self.clear_storage_check.grid(row=0, column=5, sticky="e", padx=6)
        self.write_manifest_button = self._register_device_widget(btn(manifest, "Kimlik + Donanım Yaz", self.write_identity, width=20, state="disabled"))
        # Aynı işlev üretimde tek ana buton olduğundan ikinci buton görünmez tutulur ancak mevcut kod uyumluluğu korunur.

        # Test değişkenleri iki tabda ortak kullanılır.
        fields = ["Identity", "Manifest", "Firmware", "Sensör", "Sıcaklık", "Nem", "Çiğ Noktası", "Batarya", "Şarj", "OIM3"]
        self.test_labels = {name: tk.StringVar(value="—") for name in fields}
        tests = section(prod, "4. Üretim Testi")
        tests.grid(row=3, column=0, sticky="ew", pady=4)
        for i, name in enumerate(fields):
            tests.columnconfigure(i, weight=1)
            box = tk.Frame(tests, bg=PANEL); box.grid(row=0, column=i, sticky="nsew", padx=2)
            tk.Label(box, text=name, bg=PANEL, fg=FG, font=("Segoe UI", 8, "bold")).pack()
            tk.Label(box, textvariable=self.test_labels[name], bg=PANEL, fg=FG, font=("Segoe UI", 8)).pack(pady=(3, 0))
        self.test_button = self._register_device_widget(btn(tests, "Üretim Testini Başlat", self.run_test, width=18, state="disabled"))
        self.test_button.grid(row=1, column=0, columnspan=2, sticky="w", padx=4, pady=(9, 2))
        self.save_button = self._register_device_widget(btn(tests, "CSV Kaydet", self.save_report, width=11, state="disabled"))
        self.save_button.grid(row=1, column=2, sticky="w", padx=4, pady=(9, 2))
        self.test_status_label = tk.Label(tests, textvariable=self.test_status_var, bg=PANEL, fg=MUTED, font=("Segoe UI", 9, "bold"), anchor="w")
        self.test_status_label.grid(row=1, column=3, columnspan=7, sticky="ew", padx=8, pady=(9, 2))
        self._operation_status_labels["test"] = self.test_status_label

        qrprod = section(prod, "5. QR / Etiket")
        qrprod.grid(row=4, column=0, sticky="ew", pady=4)
        self.qr_button = self._register_device_widget(btn(qrprod, "QR / Etiket Oluştur", self.create_qr_label, width=18, state="disabled"))
        self.qr_button.pack(side="left", padx=4)
        tk.Label(qrprod, text="QR yalnız üretim testi PASS olduktan sonra etkinleşir.", bg=PANEL, fg=MUTED, font=("Segoe UI", 8)).pack(side="left", padx=10)

        # -------- SERVİS --------
        sr = section(service, "1. Cihazı Oku")
        sr.grid(row=0, column=0, sticky="ew", pady=4)
        sr.columnconfigure(1, weight=1)
        self.service_read_button = self._register_device_widget(btn(sr, "Cihazı Oku", self.read_device, width=14, state="disabled"))
        self.service_read_button.grid(row=0, column=0, padx=4, pady=3)
        self.reset_read_button = self._register_device_widget(btn(sr, "Reset + Oku", self.reset_and_read, width=12, state="disabled"))
        self.reset_read_button.grid(row=0, column=1, sticky="w", padx=4)
        tk.Label(sr, textvariable=self.identity_view, bg=PANEL, fg=MUTED, font=("Segoe UI", 9), anchor="w").grid(row=1, column=0, columnspan=4, sticky="ew", padx=4, pady=(6, 2))
        self.service_read_status_var = tk.StringVar(value="Önce cihazı okuyun.")
        tk.Label(sr, textvariable=self.service_read_status_var, bg=PANEL, fg=BLUE, font=("Segoe UI", 9, "bold"), anchor="w").grid(row=2, column=0, columnspan=4, sticky="ew", padx=4)

        sfw = section(service, "2. Firmware Servisi (isteğe bağlı)")
        sfw.grid(row=1, column=0, sticky="ew", pady=4)
        sfw.columnconfigure(0, weight=1)
        tk.Label(sfw, textvariable=self.firmware_path_var, bg=PANEL, fg=FG, font=("Segoe UI", 9), anchor="w").grid(row=0, column=0, sticky="ew", padx=4)
        self.service_select_firmware_button = self._register_device_widget(btn(sfw, "Harici Firmware Seç", self.select_firmware_file, width=16, state="disabled"))
        self.service_select_firmware_button.grid(row=0, column=1, padx=4)
        self.service_embedded_firmware_button = self._register_device_widget(btn(sfw, "Gömülü Kullan", self.use_embedded_firmware, width=12, state="disabled"))
        self.service_embedded_firmware_button.grid(row=0, column=2, padx=4)
        self.service_flash_button = self._register_device_widget(btn(sfw, "Firmware Yeniden Yükle", self.flash_firmware, width=18, state="disabled"))
        self.service_flash_button.grid(row=0, column=3, padx=4)

        shw = section(service, "3. Servis / Sensör Değişikliği")
        shw.grid(row=2, column=0, sticky="ew", pady=4)
        self.service_sht45_check = self._register_device_widget(tk.Checkbutton(shw, text="Sıcaklık / Nem / Çiğ Noktası", variable=self.manifest_sht45_var, state="disabled", bg=PANEL, fg=FG, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 9)))
        self.service_sht45_check.grid(row=0, column=0, sticky="w", padx=4)
        self.service_battery_check = self._register_device_widget(tk.Checkbutton(shw, text="Battery ADC", variable=self.manifest_battery_var, state="disabled", bg=PANEL, fg=FG, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 9)))
        self.service_battery_check.grid(row=0, column=1, sticky="w", padx=4)
        self.service_manifest_summary_var = tk.StringVar(value="Cihaz okunduktan sonra mevcut/yeni donanım karşılaştırması burada gösterilir.")
        tk.Label(shw, textvariable=self.service_manifest_summary_var, bg=PANEL, fg=BLUE, font=("Segoe UI", 9, "bold"), anchor="w").grid(row=1, column=0, columnspan=4, sticky="ew", padx=4, pady=(6, 2))
        self.service_write_button = self._register_device_widget(btn(shw, "Servis Güncellemesini Yaz", self.write_identity, width=21, state="disabled"))
        self.service_write_button.grid(row=0, column=3, padx=4)
        self.service_clear_storage_check = self._register_device_widget(tk.Checkbutton(shw, text="Storage/queue temizle", variable=self.clear_storage_var, state="disabled", bg=PANEL, fg=FG, selectcolor=BG, activebackground=PANEL, activeforeground=FG, font=("Segoe UI", 8)))
        self.service_clear_storage_check.grid(row=0, column=2, padx=8)

        st = section(service, "4. Servis Testi")
        st.grid(row=3, column=0, sticky="ew", pady=4)
        for i, name in enumerate(fields):
            st.columnconfigure(i, weight=1)
            box = tk.Frame(st, bg=PANEL); box.grid(row=0, column=i, sticky="nsew", padx=2)
            tk.Label(box, text=name, bg=PANEL, fg=FG, font=("Segoe UI", 8, "bold")).pack()
            tk.Label(box, textvariable=self.test_labels[name], bg=PANEL, fg=FG, font=("Segoe UI", 8)).pack(pady=(3, 0))
        self.service_test_button = self._register_device_widget(btn(st, "Cihazı Test Et", self.run_test, width=15, state="disabled"))
        self.service_test_button.grid(row=1, column=0, columnspan=2, sticky="w", padx=4, pady=(9, 2))
        self.service_save_button = self._register_device_widget(btn(st, "CSV Kaydet", self.save_report, width=11, state="disabled"))
        self.service_save_button.grid(row=1, column=2, sticky="w", padx=4, pady=(9, 2))

        sqr = section(service, "5. QR / Teslim")
        sqr.grid(row=4, column=0, sticky="ew", pady=4)
        self.service_qr_button = self._register_device_widget(btn(sqr, "Yeni QR / Etiket", self.create_qr_label, width=17, state="disabled"))
        self.service_qr_button.pack(side="left", padx=4)
        tk.Label(sqr, text="Servis testi PASS olduğunda etkinleşir.", bg=PANEL, fg=MUTED, font=("Segoe UI", 8)).pack(side="left", padx=10)

        # Ortak teknik log
        log_wrap = tk.Frame(root, bg=BG)
        log_wrap.grid(row=3, column=0, sticky="nsew", pady=(7, 0))
        log_wrap.rowconfigure(1, weight=1); log_wrap.columnconfigure(0, weight=1)
        self.log_visible = tk.BooleanVar(value=False)
        log_head = tk.Frame(log_wrap, bg=BG); log_head.grid(row=0, column=0, sticky="ew")
        tk.Label(log_head, text="Teknik Log", bg=BG, fg=FG, font=("Segoe UI", 9, "bold")).pack(side="left")
        self.log_toggle_button = btn(log_head, "Logu Göster / Gizle", self._toggle_log, width=15)
        self.log_toggle_button.pack(side="left", padx=8)
        self.log_frame = tk.Frame(log_wrap, bg=BG, bd=1, relief="solid", highlightbackground=BORDER)
        self.log_frame.rowconfigure(0, weight=1); self.log_frame.columnconfigure(0, weight=1)
        self.log_text = tk.Text(self.log_frame, wrap="none", height=12, bg="#000716", fg="#e7edf8",
                                insertbackground="#ffffff", selectbackground="#274b7a", font=("Consolas", 9), relief="flat", bd=0)
        self.log_text.grid(row=0, column=0, sticky="nsew", padx=5, pady=5)
        sy = tk.Scrollbar(self.log_frame, orient="vertical", command=self.log_text.yview); sy.grid(row=0, column=1, sticky="ns")
        self.log_text.configure(yscrollcommand=sy.set)

        footer = tk.Frame(root, bg=BG)
        footer.grid(row=4, column=0, sticky="ew", pady=(8, 0))
        btn(footer, "Ayarlar", self.open_settings, width=10).pack(side="left")
        btn(footer, "Logu Temizle", lambda: self.log_text.delete("1.0", "end"), width=11).pack(side="left", padx=6)
        tk.Label(footer, text=f"v{APP_VERSION}", bg=BG, fg=FG, font=("Segoe UI", 8)).pack(side="right")

        for var in (self.serial_var, self.manifest_version_var, self.manifest_sht45_var, self.manifest_battery_var):
            var.trace_add("write", lambda *_: (self._refresh_manifest_preview(), self._refresh_service_manifest_summary(), self._refresh_workflow_controls()))
        self.after(0, self._refresh_manifest_preview)
        self.after(0, self._refresh_service_manifest_summary)
        self._set_device_controls(False)

    def _toggle_log(self):
        if self.log_visible.get():
            self.log_frame.grid_remove()
            self.log_visible.set(False)
        else:
            self.log_frame.grid(row=1, column=0, sticky="nsew", pady=(4, 0))
            self.log_visible.set(True)

    def _workflow_mode(self) -> str:
        try:
            return "service" if self.workflow_tabs.index(self.workflow_tabs.select()) == 1 else "production"
        except Exception:
            return "production"

    def _service_hardware_changed(self) -> bool:
        if not self._loaded_identity_serial:
            return False
        return normalize_manifest_sensor_keys(self._selected_manifest_sensor_keys()) != normalize_manifest_sensor_keys(self._loaded_manifest_sensors)

    def _refresh_service_manifest_summary(self) -> None:
        if not hasattr(self, "service_manifest_summary_var"):
            return
        if not self._loaded_identity_serial:
            self.service_manifest_summary_var.set("Cihaz okunduktan sonra mevcut/yeni donanım karşılaştırması burada gösterilir.")
            return
        old = ", ".join(self._loaded_manifest_sensors) or "—"
        new = ", ".join(self._selected_manifest_sensor_keys()) or "—"
        if self._service_hardware_changed():
            target = max(1, self._loaded_manifest_version + 1)
            self.service_manifest_summary_var.set(f"Mevcut: {old}  →  Yeni: {new}  • Donanım revizyonu v{self._loaded_manifest_version} → v{target} otomatik")
        else:
            self.service_manifest_summary_var.set(f"Mevcut: {old}  • Fiziksel donanım değişikliği yok")

    def _workflow_success(self, event: str) -> None:
        if event == "production:firmware":
            self._workflow_state["production_firmware"] = True
        elif event == "production:write":
            self._workflow_state["production_written"] = True
            self._workflow_state["production_test"] = False
        elif event == "production:test":
            self._workflow_state["production_test"] = True
        elif event == "service:read":
            self._workflow_state["service_read"] = True
            self._workflow_state["service_written"] = False
            self._workflow_state["service_test"] = False
            self.service_read_status_var.set("✓ Cihaz okundu. Servis işlemleri etkin.")
        elif event == "service:write":
            self._workflow_state["service_written"] = True
            self._workflow_state["service_test"] = False
        elif event == "service:test":
            self._workflow_state["service_test"] = True
        self._refresh_service_manifest_summary()
        self._refresh_workflow_controls()

    def _refresh_workflow_controls(self) -> None:
        if not hasattr(self, "workflow_tabs"):
            return
        connected = self._device_session_connected and not self.busy
        def setstate(widget, enabled):
            try: widget.configure(state="normal" if enabled else "disabled")
            except Exception: pass
        # Üretim: firmware -> kimlik/donanım -> test -> QR
        setstate(self.select_firmware_button, connected)
        setstate(self.embedded_firmware_button, connected)
        setstate(self.flash_button, connected)
        prod_identity = connected and self._workflow_state["production_firmware"]
        for w in (self.serial_entry, self.hwrev_entry, self.prod_entry, self.secret_entry, self.manifest_version_entry,
                  self.manifest_sht45_check, self.manifest_battery_check, self.new_secret_button, self.copy_secret_button,
                  self.clear_storage_check, self.manifest_bump_button):
            setstate(w, prod_identity)
        setstate(self.read_button, connected)
        setstate(self.write_identity_button, prod_identity)
        setstate(self.test_button, connected and self._workflow_state["production_written"])
        setstate(self.save_button, connected and self._workflow_state["production_test"])
        setstate(self.qr_button, connected and self._workflow_state["production_test"])
        # Servis: oku -> değiştir/yaz (gerekirse) -> test -> QR
        setstate(self.service_read_button, connected)
        setstate(self.reset_read_button, connected)
        service_ready = connected and self._workflow_state["service_read"]
        for w in (self.service_select_firmware_button, self.service_embedded_firmware_button, self.service_flash_button,
                  self.service_sht45_check, self.service_battery_check, self.service_clear_storage_check):
            setstate(w, service_ready)
        setstate(self.service_write_button, service_ready and self._service_hardware_changed())
        service_can_test = service_ready and (not self._service_hardware_changed() or self._workflow_state["service_written"])
        setstate(self.service_test_button, service_can_test)
        setstate(self.service_save_button, connected and self._workflow_state["service_test"])
        setstate(self.service_qr_button, connected and self._workflow_state["service_test"])

'''
s=s[:start]+new_build+s[end:]

# replace _set_device_controls
old_start=s.index('    def _set_device_controls(self, connected: bool) -> None:')
old_end=s.index('    def _set_com_connected_ui', old_start)
new_controls='''    def _set_device_controls(self, connected: bool) -> None:\n        # Önce bütün cihaz kontrollerini fail-closed kilitle; ardından iş akışı yalnız sıradaki adımları açar.\n        for widget in self._device_action_widgets + self._identity_input_widgets:\n            try:\n                widget.configure(state="disabled")\n            except Exception:\n                pass\n        if connected and not self.busy:\n            self._refresh_workflow_controls()\n\n'''
s=s[:old_start]+new_controls+s[old_end:]

# reset workflow state on disconnect, but keep on busy reconnect; in _set_com_connected_ui false branch
anchor='''        else:\n            self.com_status_var.set("COM: bağlı değil")\n'''
replace='''        else:\n            if not self.busy:\n                for key in self._workflow_state:\n                    self._workflow_state[key] = False\n                if hasattr(self, "service_read_status_var"):\n                    self.service_read_status_var.set("Önce cihazı okuyun.")\n            self.com_status_var.set("COM: bağlı değil")\n'''
if anchor not in s: raise SystemExit('disconnect anchor missing')
s=s.replace(anchor,replace,1)
# after connection branches, ensure controls refresh
anchor2='''            if self.firmware_status_var.get().startswith("Bağlantı"):\n                self._set_operation_status("firmware", "Firmware seçilebilir ve yüklenebilir.", "info")\n'''
replace2=anchor2+'''            self._refresh_workflow_controls()\n'''
s=s.replace(anchor2,replace2,1)

# drain workflow_success event
anchor='''                elif kind == "result":\n                    self._show_result(parse_log(str(text)))\n'''
replace='''                elif kind == "result":\n                    self._show_result(parse_log(str(text)))\n                elif kind == "workflow_success":\n                    self._workflow_success(str(text))\n'''
if anchor not in s: raise SystemExit('drain anchor missing')
s=s.replace(anchor,replace,1)

# _start signature/thread wrapper event
s=s.replace('''    def _start(self, label: str, fn, *, section: str | None = None, success_text: str | None = "İşlem tamamlandı"):\n''','''    def _start(self, label: str, fn, *, section: str | None = None, success_text: str | None = "İşlem tamamlandı", workflow_event: str | None = None):\n''',1)
s=s.replace('''        threading.Thread(target=self._thread_wrapper, args=(fn, section, success_text), daemon=True).start()\n\n    def _thread_wrapper(self, fn, section: str | None, success_text: str | None):\n''','''        threading.Thread(target=self._thread_wrapper, args=(fn, section, success_text, workflow_event), daemon=True).start()\n\n    def _thread_wrapper(self, fn, section: str | None, success_text: str | None, workflow_event: str | None = None):\n''',1)
s=s.replace('''            if section and success_text:\n                self.post("opstatus", (section, f"✓ {success_text}", "success"))\n            self.post("done", "Cihaz bağlı • işlemler etkin" if self._device_session_connected else "Hazır")\n''','''            if section and success_text:\n                self.post("opstatus", (section, f"✓ {success_text}", "success"))\n            if workflow_event:\n                self.post("workflow_success", workflow_event)\n            self.post("done", "Cihaz bağlı • işlemler etkin" if self._device_session_connected else "Hazır")\n''',1)

# operation calls with workflow event based on active tab
s=s.replace('''        self._start("Firmware yükleniyor...", work, section="firmware", success_text="Firmware yükleme tamamlandı • cihaz yeniden bağlandı")\n''','''        mode = self._workflow_mode()\n        self._start("Firmware yükleniyor...", work, section="firmware", success_text="Firmware yükleme tamamlandı • cihaz yeniden bağlandı", workflow_event=f"{mode}:firmware")\n''',1)
s=s.replace('''        self._start("Factory Identity + Device Manifest yazılıyor...", work, section="identity", success_text="Kimlik + manifest yazma/readback doğrulaması tamamlandı")\n''','''        mode = self._workflow_mode()\n        self._start("Factory Identity + Device Manifest yazılıyor...", work, section="identity", success_text="Kimlik + manifest yazma/readback doğrulaması tamamlandı", workflow_event=f"{mode}:write")\n''',1)
# read_device call exact occurrence, first Cihaz dinleniyor only
s=s.replace('''        self._start("Cihaz dinleniyor...", work, section="identity", success_text="Cihaz bilgisi okundu")\n''','''        mode = self._workflow_mode()\n        event = "service:read" if mode == "service" else None\n        self._start("Cihaz dinleniyor...", work, section="identity", success_text="Cihaz bilgisi okundu", workflow_event=event)\n''',1)
# reset read service read if in service
s=s.replace('''        self._start("Reset + okuma...", work, section="identity", success_text="Reset + okuma tamamlandı")\n''','''        mode = self._workflow_mode()\n        event = "service:read" if mode == "service" else None\n        self._start("Reset + okuma...", work, section="identity", success_text="Reset + okuma tamamlandı", workflow_event=event)\n''',1)
s=s.replace('''        self._start("Üretim testi çalışıyor...", work, section="test", success_text="Üretim testi tamamlandı: PASS")\n''','''        mode = self._workflow_mode()\n        self._start("Cihaz testi çalışıyor...", work, section="test", success_text="Cihaz testi tamamlandı: PASS", workflow_event=f"{mode}:test")\n''',1)

# after auto identity fill refresh service summary/controls
anchor='''            self._set_global_status("Cihaz bağlı • Factory Identity okundu", "success")\n'''
s=s.replace(anchor,anchor+'''            self._refresh_service_manifest_summary()\n            self._refresh_workflow_controls()\n''',1)
anchor='''            self._set_global_status("Cihaz bağlı • yeni cihaz", "success")\n'''
s=s.replace(anchor,anchor+'''            self._refresh_service_manifest_summary()\n            self._refresh_workflow_controls()\n''',1)

# write back
p.write_text(s,encoding='utf-8',newline='\n')
