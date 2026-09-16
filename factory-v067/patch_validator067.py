from pathlib import Path
p=Path('factory_pc_tool_v067/tools/validate_production.py')
s=p.read_text(encoding='utf-8')
s=s.replace("'progress_in_connection_area': 'self.operation_progress = ttk.Progressbar(conn' in s and 'ttk.Progressbar(fw' not in s,", "'progress_in_connection_area': ('self.operation_progress = ttk.Progressbar(conn' in s or 'self.operation_progress = ttk.Progressbar(progress_row' in s) and 'ttk.Progressbar(fw' not in s,")
s=s.replace("'service_compare_transient_safe': 'getattr(self, \"_manifest_ui_syncing\", False) or not self._loaded_identity_serial' in s and 'loaded = tuple(self._loaded_manifest_sensors or ())' in s and 'if not selected or not loaded:' in s,", "'service_compare_transient_safe': 'getattr(self, \"_manifest_ui_syncing\", False) or not self._loaded_identity_serial' in s and 'loaded = tuple(k for k in (self._loaded_manifest_sensors or ()) if k in SUPPORTED_MANIFEST_SENSOR_KEYS)' in s,")
s=s.replace("'connection_status_separate_row': 'grid(row=2, column=0, columnspan=6' in s and 'textvariable=self.com_status_var' in s,", "'connection_status_separate_row': 'progress_row = tk.Frame(conn, bg=PANEL)' in s and 'grid(row=2, column=0, columnspan=5' in s and 'textvariable=self.com_status_var' in s,")
p.write_text(s,encoding='utf-8',newline='\n')
