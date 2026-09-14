#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import hashlib
import tempfile
from types import SimpleNamespace
from contextlib import redirect_stdout, redirect_stderr
import io
import os
import queue
from collections import deque
import re
import secrets
import subprocess
import sys
import threading
import time
from dataclasses import dataclass, asdict
from datetime import date, datetime
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

try:
    import serial
    from serial.tools import list_ports
except Exception:
    serial = None
    list_ports = None

try:
    import qrcode
    from qrcode.constants import ERROR_CORRECT_M
    from PIL import Image, ImageDraw, ImageFont, ImageTk
except Exception:
    qrcode = None
    ERROR_CORRECT_M = None
    Image = None
    ImageDraw = None
    ImageFont = None
    ImageTk = None

try:
    import esptool
except Exception:
    esptool = None

try:
    from esp_idf_nvs_partition_gen import nvs_partition_gen as nvsgen
except Exception:
    nvsgen = None

APP_NAME = "VisionSen Factory Tool"
APP_VERSION = "0.4.0"
BUILD_MARKER = "standalone-production"
CONFIG_FILE = Path.home() / ".visionsen_factory_tool.json"
DEFAULT_REPORT = Path.home() / "VisionSenFactory" / "production_records.csv"
DEFAULT_LABEL_DIR = Path.home() / "VisionSenFactory" / "labels"
QR_FORMAT = "VS1"
SERIAL_RE = re.compile(r"^ESP-[0-9]{1,13}$")
PROVISION_SECRET_RE = re.compile(r"^[A-Za-z0-9]{8}$")
PROVISION_SECRET_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
VSFACT_RE = re.compile(r"VSFACT1\s+(?P<body>.+)$")

IDENTITY_RE = re.compile(
    r"Factory identity: serial=(?P<serial>\S+) hw_id=(?P<hw_id>\S+) "
    r"hw_rev=(?P<hw_rev>\S*) production_date=(?P<production_date>\S*)"
)
FIRMWARE_RE = re.compile(r"Firmware\s*:\s*(?P<firmware>[0-9]+\.[0-9]+\.[0-9]+)")
SHT_RE = re.compile(r"SHT45\s*:\s*temp=(?P<temp>-?[0-9.]+) C humidity=(?P<humidity>-?[0-9.]+) %")
DEW_RE = re.compile(r"Dew point\s*:\s*(?P<dew>-?[0-9.]+) C")
BATTERY_OK_RE = re.compile(r"Battery\s*:\s*(?P<voltage>[0-9.]+) V / (?P<pct>[0-9.]+) %")
BATTERY_BAD_RE = re.compile(r"Battery\s*:\s*(?P<status>[A-Z0-9_]+).*?inferred=(?P<voltage>[0-9.]+) V")
CHARGE_RE = re.compile(r"Charging\s*:\s*(?P<charging>YES|NO|UNKNOWN)")
WIFI_RE = re.compile(r"Wi-Fi result\s*:\s*(?P<wifi>OK|FAILED)(?P<rest>.*)")
OIM_RE = re.compile(r"OIM3 result\s*:\s*(?P<oim>[A-Z0-9_]+)")
SENSOR_INIT_RE = re.compile(r"Sensor init\s*:\s*(?P<sensor_init>OK|PARTIAL/FAILED)")


def provisioning_qr_payload(serial_no: str, secret: str) -> str:
    serial_no = serial_no.strip().upper()
    secret = secret.strip()
    if not SERIAL_RE.fullmatch(serial_no):
        raise ValueError("Seri no ESP-<rakamlar> formatında olmalı.")
    if not PROVISION_SECRET_RE.fullmatch(secret):
        raise ValueError("Kurulum kodu tam 8 karakter olmalı ve yalnız harf/rakam içermeli.")
    return f"{QR_FORMAT}|{serial_no}|{secret}"


def _label_font(size: int, bold: bool = False):
    if ImageFont is None:
        return None
    candidates = []
    if os.name == "nt":
        candidates.extend([
            Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts" / ("segoeuib.ttf" if bold else "segoeui.ttf"),
            Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts" / ("arialbd.ttf" if bold else "arial.ttf"),
        ])
    candidates.extend([
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    ])
    for candidate in candidates:
        try:
            if candidate.is_file():
                return ImageFont.truetype(str(candidate), size=size)
        except Exception:
            pass
    return ImageFont.load_default()


def build_qr_label(serial_no: str, secret: str):
    if qrcode is None or Image is None or ImageDraw is None or ImageFont is None:
        raise RuntimeError("QR/etiket için qrcode ve Pillow gerekli.")
    payload = provisioning_qr_payload(serial_no, secret)
    qr = qrcode.QRCode(
        version=None,
        error_correction=ERROR_CORRECT_M,
        box_size=10,
        border=4,
    )
    qr.add_data(payload)
    qr.make(fit=True)
    qr_img = qr.make_image(fill_color="black", back_color="white").convert("RGB")
    qr_img.thumbnail((330, 330))

    canvas = Image.new("RGB", (840, 390), "white")
    canvas.paste(qr_img, (28, 28))
    draw = ImageDraw.Draw(canvas)
    title_font = _label_font(34, bold=True)
    normal_font = _label_font(25)
    small_font = _label_font(18)
    x = 390
    draw.text((x, 52), "VisionSen OIM3", fill="black", font=title_font)
    draw.text((x, 122), f"S/N: {serial_no}", fill="black", font=normal_font)
    draw.text((x, 176), f"SETUP: {secret}", fill="black", font=normal_font)
    draw.text((x, 242), "QR: cihaz kurulumu", fill="black", font=small_font)
    draw.text((x, 280), payload, fill="black", font=small_font)
    draw.rectangle((12, 12, 828, 378), outline="black", width=2)
    return canvas, payload


@dataclass
class Settings:
    idf_python: str = r"C:\Espressif\tools\python\v6.1\venv\Scripts\python.exe"
    idf_path: str = r"C:\esp\v6.1\esp-idf"
    idf_tools_path: str = r"C:\Espressif"
    firmware_project: str = r"C:\ESP32\workspace\visionsen_oim3_idf_v2_1_7_qr_factory"
    flash_baud: int = 460800
    monitor_baud: int = 115200
    test_seconds: int = 12
    report_csv: str = str(DEFAULT_REPORT)

    @classmethod
    def load(cls) -> "Settings":
        try:
            data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
            allowed = {k: v for k, v in data.items() if k in cls.__dataclass_fields__}
            return cls(**allowed)
        except Exception:
            return cls()

    def save(self) -> None:
        CONFIG_FILE.write_text(json.dumps(asdict(self), indent=2, ensure_ascii=False), encoding="utf-8")


@dataclass
class TestResult:
    serial: str = ""
    hw_id: str = ""
    hw_rev: str = ""
    production_date: str = ""
    factory_schema: str = ""
    firmware: str = ""
    sensor_init: str = ""
    sht45_found: bool = False
    temperature: str = ""
    humidity: str = ""
    dew_point: str = ""
    battery_status: str = ""
    battery_voltage: str = ""
    charging: str = ""
    wifi: str = ""
    oim3: str = ""
    unconfigured: bool = False

    @property
    def identity_ok(self) -> bool:
        return bool(self.serial and self.hw_id and self.factory_schema == "2")

    @property
    def sensor_ok(self) -> bool:
        return self.sht45_found and bool(self.temperature and self.humidity)

    @property
    def overall(self) -> str:
        if self.identity_ok and self.sensor_ok and self.firmware:
            return "PASS"
        return "FAIL"


def parse_log(text: str) -> TestResult:
    r = TestResult()
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if "NOT CONFIGURED" in line:
            r.unconfigured = True
        m = IDENTITY_RE.search(line)
        if m:
            r.serial = m.group("serial")
            r.hw_id = m.group("hw_id")
            r.hw_rev = m.group("hw_rev")
            r.production_date = m.group("production_date")
        if "Factory schema" in line:
            vals = re.findall(r"\d+", line)
            if vals:
                r.factory_schema = vals[-1]
        m = FIRMWARE_RE.search(line)
        if m:
            r.firmware = m.group("firmware")
        m = SENSOR_INIT_RE.search(line)
        if m:
            r.sensor_init = m.group("sensor_init")
        m = SHT_RE.search(line)
        if m:
            r.sht45_found = True
            r.temperature = m.group("temp")
            r.humidity = m.group("humidity")
        m = DEW_RE.search(line)
        if m:
            r.dew_point = m.group("dew")
        m = BATTERY_OK_RE.search(line)
        if m:
            r.battery_status = "OK"
            r.battery_voltage = m.group("voltage")
        m = BATTERY_BAD_RE.search(line)
        if m:
            r.battery_status = m.group("status")
            r.battery_voltage = m.group("voltage")
        m = CHARGE_RE.search(line)
        if m:
            r.charging = m.group("charging")
        m = WIFI_RE.search(line)
        if m:
            r.wifi = m.group("wifi")
        m = OIM_RE.search(line)
        if m:
            r.oim3 = m.group("oim")
        m = VSFACT_RE.search(line)
        if m:
            body = m.group("body")
            fields = {}
            for item in body.split():
                if "=" in item:
                    key, value = item.split("=", 1)
                    fields[key] = value
            r.serial = fields.get("serial", r.serial)
            r.hw_id = fields.get("hw_id", r.hw_id)
            r.firmware = fields.get("fw", r.firmware)
            r.factory_schema = fields.get("schema", r.factory_schema)
            r.sensor_init = fields.get("sensor_init", r.sensor_init)
            r.sht45_found = fields.get("sht45") == "PASS"
            r.temperature = "" if fields.get("temp_c") in (None, "NA") else fields.get("temp_c", "")
            r.humidity = "" if fields.get("humidity_pct") in (None, "NA") else fields.get("humidity_pct", "")
            r.dew_point = "" if fields.get("dew_point_c") in (None, "NA") else fields.get("dew_point_c", "")
            r.battery_status = fields.get("battery_status", r.battery_status)
            r.battery_voltage = "" if fields.get("battery_v") in (None, "NA") else fields.get("battery_v", "")
            r.charging = fields.get("charging", r.charging)
    return r


class VisionSenFactoryApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f"{APP_NAME} v{APP_VERSION} [{BUILD_MARKER}]")
        self.geometry("1120x760")
        self.minsize(980, 680)
        self.settings = Settings.load()
        self.msgq: queue.Queue[tuple[str, str]] = queue.Queue()
        self.busy = False
        self.last_result = TestResult()
        self.last_log = ""
        self._idf_env_cache_key: tuple[str, str, str] | None = None
        self._idf_env_cache: dict[str, str] | None = None
        self._monitor_serial = None
        self._monitor_stop = threading.Event()
        self._monitor_thread: threading.Thread | None = None
        self._qr_preview_ref = None
        self._device_session_connected = False
        self._device_action_widgets = []
        self._identity_input_widgets = []
        self._build_ui()
        self.refresh_ports()
        self.protocol("WM_DELETE_WINDOW", self._on_close)
        self.after(100, self._drain_messages)

    def _register_device_widget(self, widget):
        self._device_action_widgets.append(widget)
        return widget

    def _register_identity_input(self, widget):
        self._identity_input_widgets.append(widget)
        return widget

    def _build_ui(self):
        style = ttk.Style(self)
        try:
            if "vista" in style.theme_names():
                style.theme_use("vista")
        except Exception:
            pass

        root = ttk.Frame(self, padding=10)
        root.pack(fill="both", expand=True)
        root.columnconfigure(0, weight=1)
        root.rowconfigure(4, weight=1)

        header = ttk.Frame(root)
        header.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        ttk.Label(header, text="VisionSen Factory Tool", font=("Segoe UI", 15, "bold")).pack(side="left")
        ttk.Label(header, text="OIM3 Üretim / QA", font=("Segoe UI", 9)).pack(side="left", padx=(12, 0))
        self.global_status = ttk.Label(header, text="Cihaz bağlantısı bekleniyor")
        self.global_status.pack(side="right")

        conn = ttk.LabelFrame(root, text="1. Cihaz bağlantısı", padding=9)
        conn.grid(row=1, column=0, sticky="ew", pady=4)
        conn.columnconfigure(1, weight=1)
        ttk.Label(conn, text="COM Port").grid(row=0, column=0, sticky="w")
        self.port_var = tk.StringVar()
        self.port_combo = ttk.Combobox(conn, textvariable=self.port_var, width=24, state="readonly")
        self.port_combo.grid(row=0, column=1, sticky="ew", padx=6)
        self.refresh_button = ttk.Button(conn, text="Yenile", command=self.refresh_ports)
        self.refresh_button.grid(row=0, column=2, padx=4)
        self.connect_button = ttk.Button(conn, text="Bağlan", command=self.connect_com)
        self.connect_button.grid(row=0, column=3, padx=4)
        self.disconnect_button = ttk.Button(conn, text="Bağlantıyı Kes", command=self.disconnect_com, state="disabled")
        self.disconnect_button.grid(row=0, column=4, padx=4)
        self.com_status_var = tk.StringVar(value="COM: bağlı değil")
        ttk.Label(conn, textvariable=self.com_status_var, font=("Segoe UI", 9, "bold")).grid(row=0, column=5, sticky="w", padx=(10, 4))

        self.firmware_info_var = tk.StringVar(value="Firmware paketi: OIM3 v2.1.7 • Standalone")
        ttk.Label(conn, textvariable=self.firmware_info_var).grid(row=1, column=0, columnspan=4, sticky="w", pady=(8, 0))
        self.flash_button = self._register_device_widget(ttk.Button(conn, text="Firmware Yükle", command=self.flash_firmware, state="disabled"))
        self.flash_button.grid(row=1, column=4, padx=4, pady=(8,0))
        ttk.Label(conn, text="ESP-IDF / Python kurulumu gerekmez").grid(row=1, column=5, sticky="w", padx=(10,4), pady=(8,0))

        ident = ttk.LabelFrame(root, text="2. Factory identity", padding=9)
        ident.grid(row=2, column=0, sticky="ew", pady=4)
        for c in range(7):
            ident.columnconfigure(c, weight=1 if c in (1,3,5) else 0)

        ttk.Label(ident, text="Seri No").grid(row=0, column=0, sticky="w")
        self.serial_var = tk.StringVar(value="ESP-001")
        self.serial_entry = self._register_identity_input(ttk.Entry(ident, textvariable=self.serial_var, width=18, state="disabled"))
        self.serial_entry.grid(row=0, column=1, sticky="ew", padx=6)
        ttk.Label(ident, text="HW Rev").grid(row=0, column=2, sticky="w")
        self.hwrev_var = tk.StringVar(value="OIM3-R1")
        self.hwrev_entry = self._register_identity_input(ttk.Entry(ident, textvariable=self.hwrev_var, width=18, state="disabled"))
        self.hwrev_entry.grid(row=0, column=3, sticky="ew", padx=6)
        ttk.Label(ident, text="Üretim Tarihi").grid(row=0, column=4, sticky="w")
        self.prod_var = tk.StringVar(value=date.today().isoformat())
        self.prod_entry = self._register_identity_input(ttk.Entry(ident, textvariable=self.prod_var, width=14, state="disabled"))
        self.prod_entry.grid(row=0, column=5, sticky="ew", padx=6)
        self.write_identity_button = self._register_device_widget(ttk.Button(ident, text="Kimliği Yaz / Güncelle", command=self.write_identity, state="disabled"))
        self.write_identity_button.grid(row=0, column=6, padx=4)

        ttk.Label(ident, text="Kurulum Kodu (8)").grid(row=1, column=0, sticky="w", pady=(8,0))
        self.prov_secret_var = tk.StringVar(value=self.generate_secret())
        self.secret_entry = self._register_identity_input(ttk.Entry(ident, textvariable=self.prov_secret_var, width=18, state="disabled"))
        self.secret_entry.grid(row=1, column=1, columnspan=2, sticky="ew", padx=6, pady=(8,0))
        self.new_secret_button = self._register_device_widget(ttk.Button(ident, text="Yeni Kod", command=lambda: self.prov_secret_var.set(self.generate_secret()), state="disabled"))
        self.new_secret_button.grid(row=1, column=3, padx=4, pady=(8,0))
        self.copy_secret_button = self._register_device_widget(ttk.Button(ident, text="Kopyala", command=self.copy_secret, state="disabled"))
        self.copy_secret_button.grid(row=1, column=4, padx=4, pady=(8,0))
        self.qr_button = self._register_device_widget(ttk.Button(ident, text="QR / Etiket", command=self.create_qr_label, state="disabled"))
        self.qr_button.grid(row=1, column=5, padx=4, pady=(8,0))
        self.clear_storage_var = tk.BooleanVar(value=True)
        self.clear_storage_check = self._register_device_widget(ttk.Checkbutton(ident, text="Re-issue: storage temizle", variable=self.clear_storage_var, state="disabled"))
        self.clear_storage_check.grid(row=1, column=6, sticky="w", pady=(8,0))

        self.identity_view = tk.StringVar(value="Cihaz kimliği henüz okunmadı")
        ttk.Label(ident, textvariable=self.identity_view).grid(row=2, column=0, columnspan=5, sticky="w", pady=(8,0))
        self.read_button = self._register_device_widget(ttk.Button(ident, text="Cihazdan Oku", command=self.read_device, state="disabled"))
        self.read_button.grid(row=2, column=5, padx=4, pady=(8,0))
        self.reset_read_button = self._register_device_widget(ttk.Button(ident, text="Reset + Oku", command=self.reset_and_read, state="disabled"))
        self.reset_read_button.grid(row=2, column=6, padx=4, pady=(8,0))

        tests = ttk.LabelFrame(root, text="3. Üretim testi", padding=9)
        tests.grid(row=3, column=0, sticky="ew", pady=4)
        tests.columnconfigure(8, weight=1)
        self.test_labels = {}
        fields = ["Identity", "Firmware", "SHT45", "Sıcaklık", "Nem", "Çiy", "Batarya", "Şarj", "OIM3"]
        for i, name in enumerate(fields):
            box = ttk.Frame(tests, padding=4)
            box.grid(row=0, column=i, sticky="nsew")
            ttk.Label(box, text=name, font=("Segoe UI", 9, "bold")).pack()
            v = tk.StringVar(value="—")
            ttk.Label(box, textvariable=v).pack()
            self.test_labels[name] = v
        self.test_button = self._register_device_widget(ttk.Button(tests, text="Testi Başlat", command=self.run_test, state="disabled"))
        self.test_button.grid(row=1, column=0, padx=4, pady=(8,0), sticky="w")
        self.save_button = self._register_device_widget(ttk.Button(tests, text="Sonucu CSV'ye Kaydet", command=self.save_report, state="disabled"))
        self.save_button.grid(row=1, column=1, columnspan=2, padx=4, pady=(8,0), sticky="w")
        ttk.Label(tests, text="Bağlantı kurulmadan cihaz üzerinde hiçbir yazma, güncelleme veya test işlemi etkin değildir.").grid(row=1, column=3, columnspan=6, sticky="w", padx=6, pady=(8,0))

        logs = ttk.LabelFrame(root, text="İşlem / cihaz logu", padding=6)
        logs.grid(row=4, column=0, sticky="nsew", pady=4)
        logs.rowconfigure(0, weight=1); logs.columnconfigure(0, weight=1)
        self.log_text = tk.Text(logs, wrap="none", height=18, font=("Consolas", 9), state="normal")
        self.log_text.grid(row=0, column=0, sticky="nsew")
        sy = ttk.Scrollbar(logs, orient="vertical", command=self.log_text.yview)
        sy.grid(row=0, column=1, sticky="ns"); self.log_text.configure(yscrollcommand=sy.set)

        footer = ttk.Frame(root)
        footer.grid(row=5, column=0, sticky="ew", pady=(6,0))
        ttk.Button(footer, text="Ayarlar", command=self.open_settings).pack(side="left")
        ttk.Button(footer, text="Logu Temizle", command=lambda: self.log_text.delete("1.0", "end")).pack(side="left", padx=6)
        ttk.Label(footer, text=f"v{APP_VERSION} · {BUILD_MARKER}").pack(side="right")

        self._set_device_controls(False)

    def post(self, kind: str, text: str):
        self.msgq.put((kind, text))

    def _drain_messages(self):
        try:
            while True:
                kind, text = self.msgq.get_nowait()
                if kind == "log":
                    self.log_text.insert("end", text)
                    self.log_text.see("end")
                elif kind == "status":
                    self.global_status.config(text=text)
                elif kind == "done":
                    self.busy = False
                    self.global_status.config(text=text or "Hazır")
                elif kind == "error":
                    self.busy = False
                    self.global_status.config(text="Hata")
                    messagebox.showerror(APP_NAME, text)
                elif kind == "result":
                    self._show_result(parse_log(text))
                elif kind == "connection":
                    self._set_com_connected_ui(text == "1")
        except queue.Empty:
            pass
        self.after(100, self._drain_messages)

    def _start(self, label: str, fn):
        if self.busy:
            messagebox.showwarning(APP_NAME, "Başka bir işlem devam ediyor.")
            return
        self.busy = True
        self.global_status.config(text=label)
        threading.Thread(target=self._thread_wrapper, args=(fn,), daemon=True).start()

    def _thread_wrapper(self, fn):
        try:
            fn()
        except Exception as exc:
            self.post("error", str(exc))
        else:
            self.post("done", "Cihaz bağlı • işlemler etkin" if self._device_session_connected else "Hazır")

    def refresh_ports(self):
        if list_ports is None:
            self.port_combo["values"] = []
            self.global_status.config(text="pyserial gerekli")
            return
        ports = [p.device for p in list_ports.comports()]
        self.port_combo["values"] = ports
        if ports and self.port_var.get() not in ports:
            self.port_var.set(ports[0])
        elif not ports:
            self.port_var.set("")

    def select_project(self):
        pass

    def require_port(self) -> str:
        port = self.port_var.get().strip()
        if not port:
            raise RuntimeError("COM port seçin.")
        return port

    def require_project(self) -> Path:
        return Path(self.settings.firmware_project)

    def _set_device_controls(self, connected: bool) -> None:
        state = "normal" if connected else "disabled"
        for widget in self._device_action_widgets:
            try:
                widget.configure(state=state)
            except Exception:
                pass
        for widget in self._identity_input_widgets:
            try:
                widget.configure(state=state)
            except Exception:
                pass

    def _set_com_connected_ui(self, connected: bool):
        self._device_session_connected = bool(connected)
        if connected:
            self.com_status_var.set(f"COM: bağlı ({self.port_var.get().strip()})")
            self.connect_button.configure(state="disabled")
            self.disconnect_button.configure(state="normal")
            self.port_combo.configure(state="disabled")
            self.refresh_button.configure(state="disabled")
            self._set_device_controls(True)
        else:
            self.com_status_var.set("COM: bağlı değil")
            self.connect_button.configure(state="normal")
            self.disconnect_button.configure(state="disabled")
            self.port_combo.configure(state="readonly")
            self.refresh_button.configure(state="normal")
            self._set_device_controls(False)

    def require_connected(self) -> None:
        if not self._device_session_connected or self._monitor_serial is None or not getattr(self._monitor_serial, "is_open", False):
            raise RuntimeError("Önce COM portunu seçip Bağlan düğmesine basın. Cihaz bağlantısı doğrulanmadan işlem yapılamaz.")

    @staticmethod
    def _pulse_esp_reset(ser) -> None:
        try:
            ser.setDTR(False)
            ser.setRTS(True)
            time.sleep(0.12)
            ser.setRTS(False)
            ser.setDTR(False)
            time.sleep(0.08)
        except Exception as exc:
            raise RuntimeError(f"ESP reset hattı sürülemedi: {exc}") from exc

    def _monitor_loop(self, ser) -> None:
        while not self._monitor_stop.is_set():
            try:
                raw = ser.readline()
                if raw:
                    self.post("log", raw.decode("utf-8", errors="replace"))
            except Exception as exc:
                if not self._monitor_stop.is_set():
                    self.post("log", f"\n[COM] Okuma durdu: {exc}\n")
                    self.post("connection", "0")
                break

    def _open_verified_serial(self, port: str, verify_timeout: float = 4.0):
        if serial is None:
            raise RuntimeError("pyserial uygulama paketinde bulunamadı.")
        ser = serial.Serial()
        ser.port = port
        ser.baudrate = self.settings.monitor_baud
        ser.timeout = 0.15
        ser.write_timeout = 1.0
        ser.rtscts = False
        ser.dsrdtr = False
        ser.dtr = False
        ser.rts = False
        ser.open()
        try:
            try:
                ser.reset_input_buffer()
            except Exception:
                pass
            self._pulse_esp_reset(ser)
            deadline = time.monotonic() + verify_timeout
            captured = []
            verified = False
            signatures = ("Firmware       :", "VSFACT1 ", "VisionSen", "OIM3")
            while time.monotonic() < deadline:
                raw = ser.readline()
                if not raw:
                    continue
                line = raw.decode("utf-8", errors="replace")
                captured.append(line)
                self.post("log", line)
                if any(sig in line for sig in signatures):
                    verified = True
                    break
            if not verified:
                excerpt = "".join(captured[-8:]).strip()
                detail = f"\n\nAlınan çıktı:\n{excerpt}" if excerpt else ""
                raise RuntimeError(
                    "COM port açıldı ancak VisionSen OIM3 cihazı doğrulanamadı. "
                    "Doğru COM portunu seçin ve cihazın USB/UART bağlantısını kontrol edin." + detail
                )
            return ser
        except Exception:
            try:
                ser.close()
            except Exception:
                pass
            raise

    def connect_com(self):
        if self.busy:
            messagebox.showwarning(APP_NAME, "İşlem devam ederken COM bağlantısı açılamaz.")
            return
        if self._monitor_serial is not None:
            return
        try:
            port = self.require_port()
            self.global_status.config(text="Cihaz bağlantısı doğrulanıyor...")
            self.update_idletasks()
            ser = self._open_verified_serial(port)
        except Exception as exc:
            self._set_com_connected_ui(False)
            self.global_status.config(text="Bağlantı başarısız")
            messagebox.showerror(APP_NAME, str(exc))
            return
        self._monitor_serial = ser
        self._monitor_stop.clear()
        self._monitor_thread = threading.Thread(target=self._monitor_loop, args=(ser,), daemon=True)
        self._monitor_thread.start()
        self._set_com_connected_ui(True)
        self.global_status.config(text="Cihaz bağlı • işlemler etkin")
        self.log_text.insert("end", f"\n[COM] {port} VisionSen OIM3 olarak doğrulandı ve bağlandı.\n")
        self.log_text.see("end")

    def _close_com_internal(self, *, reset: bool, notify: bool = True, keep_session: bool = False) -> None:
        ser = self._monitor_serial
        if ser is None:
            if notify and not keep_session:
                self.post("connection", "0")
            return
        self._monitor_stop.set()
        thread = self._monitor_thread
        if thread is not None and thread.is_alive() and thread is not threading.current_thread():
            thread.join(timeout=0.8)
        reset_error = None
        try:
            if reset and getattr(ser, "is_open", False):
                self._pulse_esp_reset(ser)
        except Exception as exc:
            reset_error = exc
        try:
            if getattr(ser, "is_open", False):
                ser.close()
        finally:
            self._monitor_serial = None
            self._monitor_thread = None
        if notify and not keep_session:
            self.post("connection", "0")
        if reset_error is not None:
            raise reset_error

    def disconnect_com(self):
        if self.busy:
            messagebox.showwarning(APP_NAME, "İşlem devam ederken bağlantı kesilemez.")
            return
        try:
            self._close_com_internal(reset=True, notify=False, keep_session=False)
        finally:
            self._set_com_connected_ui(False)
        self.global_status.config(text="Bağlantı kesildi • ESP32 resetlendi")
        self.log_text.insert("end", "\n[COM] Bağlantı kapatıldı; ESP32 normal çalışmaya resetlendi.\n")
        self.log_text.see("end")

    def _release_com_for_operation(self) -> None:
        self.require_connected()
        self.post("log", "\n[COM] İşlem için seri port geçici olarak serbest bırakılıyor.\n")
        self._close_com_internal(reset=False, notify=False, keep_session=True)

    def _reconnect_after_operation(self, verify_timeout: float = 6.0) -> None:
        port = self.require_port()
        deadline = time.monotonic() + 8.0
        last_error = None
        while time.monotonic() < deadline:
            try:
                ser = self._open_verified_serial(port, verify_timeout=verify_timeout)
                self._monitor_serial = ser
                self._monitor_stop.clear()
                self._monitor_thread = threading.Thread(target=self._monitor_loop, args=(ser,), daemon=True)
                self._monitor_thread.start()
                self.post("connection", "1")
                self.post("log", "\n[COM] İşlem sonrası cihaz yeniden doğrulandı ve bağlantı açıldı.\n")
                return
            except Exception as exc:
                last_error = exc
                time.sleep(0.5)
        self.post("connection", "0")
        raise RuntimeError(f"İşlem tamamlandı ancak cihazla bağlantı yeniden kurulamadı: {last_error}")

    @staticmethod
    def _resource_root() -> Path:
        return Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))

    def _firmware_dir(self) -> Path:
        p = self._resource_root() / "firmware"
        if not p.is_dir():
            raise RuntimeError("EXE içindeki firmware paketi bulunamadı.")
        return p

    def _run_esptool(self, args: list[str]) -> None:
        if esptool is None:
            raise RuntimeError("Standalone esptool bileşeni uygulama paketinde bulunamadı.")
        buf = io.StringIO()
        try:
            with redirect_stdout(buf), redirect_stderr(buf):
                result = esptool.main(args)
            if isinstance(result, int) and result != 0:
                raise RuntimeError(f"esptool exit={result}")
        except SystemExit as exc:
            if exc.code not in (0, None):
                out = buf.getvalue()
                raise RuntimeError(f"esptool başarısız (exit={exc.code}).\n{out[-4000:]}") from exc
        except Exception as exc:
            out = buf.getvalue()
            if out:
                self.post("log", out)
            raise RuntimeError(f"esptool işlemi başarısız: {exc}") from exc
        out = buf.getvalue()
        if out:
            self.post("log", out)

    def _firmware_flash_args(self, port: str) -> list[str]:
        fw = self._firmware_dir()
        manifest = fw / "flasher_args.json"
        if not manifest.is_file():
            raise RuntimeError("Firmware flasher_args.json bulunamadı.")
        data = json.loads(manifest.read_text(encoding="utf-8"))
        flash_files = data.get("flash_files") or {}
        if not flash_files:
            raise RuntimeError("Firmware manifestinde flash_files boş.")
        extra = data.get("extra_esptool_args") or {}
        chip = str(extra.get("chip") or "esp32")
        args = ["--chip", chip, "--port", port, "--baud", str(self.settings.flash_baud), "--before", "default-reset", "--after", "hard-reset", "write-flash"]
        for address, rel in sorted(flash_files.items(), key=lambda kv: int(str(kv[0]), 0)):
            path = fw / str(rel).replace("/", os.sep)
            if not path.is_file():
                alt = fw / Path(str(rel)).name
                if alt.is_file():
                    path = alt
                else:
                    raise RuntimeError(f"Firmware bileşeni bulunamadı: {rel}")
            args += [str(address), str(path)]
        return args

    def flash_firmware(self):
        try:
            self.require_connected()
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc)); return
        if not messagebox.askyesno(APP_NAME, "OIM3 v2.1.7 firmware cihaza yüklensin mi?\n\nFactory identity bölümü korunacaktır."):
            return
        def work():
            port = self.require_port()
            self._release_com_for_operation()
            try:
                self._run_esptool(self._firmware_flash_args(port))
                self.post("log", "\n[FLASH] Standalone firmware yükleme tamamlandı. factory_data korundu.\n")
            finally:
                self._reconnect_after_operation()
        self._start("Firmware yükleniyor...", work)

    @staticmethod
    def generate_secret(length: int = 8) -> str:
        return "".join(secrets.choice(PROVISION_SECRET_ALPHABET) for _ in range(length))

    def copy_secret(self):
        try:
            self.require_connected()
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc)); return
        secret = self.prov_secret_var.get().strip()
        self.clipboard_clear(); self.clipboard_append(secret)
        self.global_status.config(text="Kurulum kodu panoya kopyalandı")

    def _save_label(self, path: Path, serial_no: str, secret: str) -> tuple[Path, str]:
        image, payload = build_qr_label(serial_no, secret)
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path, format="PNG")
        return path, payload

    def _default_label_path(self, serial_no: str) -> Path:
        return DEFAULT_LABEL_DIR / f"{serial_no}-label.png"

    def create_qr_label(self):
        try:
            self.require_connected()
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc)); return
        serial_no = self.serial_var.get().strip().upper()
        secret = self.prov_secret_var.get().strip()
        try:
            provisioning_qr_payload(serial_no, secret)
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc))
            return
        default_path = self._default_label_path(serial_no)
        default_path.parent.mkdir(parents=True, exist_ok=True)
        path_text = filedialog.asksaveasfilename(
            title="QR / cihaz etiketini kaydet",
            initialdir=str(default_path.parent),
            initialfile=default_path.name,
            defaultextension=".png",
            filetypes=[("PNG görüntü", "*.png")],
        )
        if not path_text:
            return
        try:
            path, payload = self._save_label(Path(path_text), serial_no, secret)
            self.global_status.config(text="QR etiketi oluşturuldu")
            self.log_text.insert("end", f"\n[QR] {path}\n[QR] {payload}\n")
            self.log_text.see("end")
            if ImageTk is not None:
                image = Image.open(path)
                image.thumbnail((720, 340))
                preview = ImageTk.PhotoImage(image)
                self._qr_preview_ref = preview
                w = tk.Toplevel(self)
                w.title(f"{serial_no} QR / Etiket")
                ttk.Label(w, image=preview).pack(padx=12, pady=12)
                ttk.Label(w, text=f"QR içeriği: {payload}").pack(padx=12, pady=(0, 12))
        except Exception as exc:
            messagebox.showerror(APP_NAME, f"QR etiketi oluşturulamadı:\n{exc}")

    def _generate_factory_nvs(self, serial_no: str, hwrev: str, prod: str, secret: str, output: Path) -> None:
        if nvsgen is None:
            raise RuntimeError("Standalone NVS generator uygulama paketinde bulunamadı.")
        output.parent.mkdir(parents=True, exist_ok=True)
        csv_path = output.with_suffix(".csv")
        with csv_path.open("w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["key", "type", "encoding", "value"])
            w.writerow(["identity", "namespace", "", ""])
            w.writerow(["schema", "data", "u32", "2"])
            w.writerow(["serial", "data", "string", serial_no])
            if hwrev:
                w.writerow(["hwrev", "data", "string", hwrev])
            if prod:
                w.writerow(["prod_date", "data", "string", prod])
            w.writerow(["prov_secret", "data", "string", secret])
        args = SimpleNamespace(input=[str(csv_path)], output=output.name, size="0x6000", version=2, outdir=str(output.parent))
        nvsgen.generate(args)
        try:
            csv_path.unlink()
        except Exception:
            pass
        if not output.is_file() or output.stat().st_size != 0x6000:
            raise RuntimeError("factory_data NVS image üretilemedi veya boyutu geçersiz.")

    @staticmethod
    def _sha256_file(path: Path) -> str:
        h = hashlib.sha256()
        with path.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        return h.hexdigest()

    def write_identity(self):
        try:
            self.require_connected()
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc)); return
        serial_no = self.serial_var.get().strip().upper()
        hwrev = self.hwrev_var.get().strip()
        prod = self.prod_var.get().strip()
        prov_secret = self.prov_secret_var.get().strip()
        if not SERIAL_RE.fullmatch(serial_no):
            messagebox.showerror(APP_NAME, "Seri no ESP-<rakamlar> formatında olmalı. Örnek: ESP-001"); return
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", prod):
            messagebox.showerror(APP_NAME, "Üretim tarihi YYYY-MM-DD formatında olmalı."); return
        if not PROVISION_SECRET_RE.fullmatch(prov_secret):
            messagebox.showerror(APP_NAME, "Kurulum kodu tam 8 karakter olmalı ve yalnız harf/rakam içermeli."); return
        if not messagebox.askyesno(APP_NAME, f"factory_data kimliği {serial_no} olarak yazılsın/güncellensin mi?\n\nBu işlem mevcut factory identity değerlerini değiştirir."):
            return
        def work():
            port = self.require_port()
            self._release_com_for_operation()
            try:
                with tempfile.TemporaryDirectory(prefix="visionsen_factory_") as td:
                    image = Path(td) / "factory_data.bin"
                    self._generate_factory_nvs(serial_no, hwrev, prod, prov_secret, image)
                    self._run_esptool(["--chip", "esp32", "--port", port, "--baud", str(self.settings.flash_baud), "write-flash", "0x12000", str(image)])
                    readback = Path(td) / "factory_data.readback.bin"
                    self._run_esptool(["--chip", "esp32", "--port", port, "--baud", str(self.settings.flash_baud), "read-flash", "0x12000", "0x6000", str(readback)])
                    if self._sha256_file(readback) != self._sha256_file(image):
                        raise RuntimeError("factory_data readback doğrulaması başarısız.")
                    self.post("log", "[IDENTITY] factory_data yazma/readback PASS.\n")
                    if self.clear_storage_var.get():
                        self._run_esptool(["--chip", "esp32", "--port", port, "--baud", str(self.settings.flash_baud), "erase-region", "0x320000", "0x0E0000"])
                        self.post("log", "[IDENTITY] storage temizleme PASS.\n")
                label_path, payload = self._save_label(self._default_label_path(serial_no), serial_no, prov_secret)
                self.post("log", f"QR/etiket otomatik oluşturuldu: {label_path}\nQR: {payload}\n")
            finally:
                self._reconnect_after_operation()
        self._start("Factory identity yazılıyor...", work)

    def _stop_monitor_reader(self) -> None:
        self._monitor_stop.set()
        thread = self._monitor_thread
        if thread is not None and thread.is_alive() and thread is not threading.current_thread():
            thread.join(timeout=1.0)
        self._monitor_thread = None

    def _start_monitor_reader(self) -> None:
        ser = self._monitor_serial
        if ser is None or not getattr(ser, "is_open", False):
            return
        self._monitor_stop.clear()
        self._monitor_thread = threading.Thread(target=self._monitor_loop, args=(ser,), daemon=True)
        self._monitor_thread.start()

    def _capture_with_existing_connection(self, seconds: int, reset: bool = False) -> str:
        self.require_connected()
        ser = self._monitor_serial
        self._stop_monitor_reader()
        try:
            if reset:
                try:
                    ser.reset_input_buffer()
                except Exception:
                    pass
                self._pulse_esp_reset(ser)
            deadline = time.monotonic() + seconds
            chunks: list[str] = []
            while time.monotonic() < deadline:
                raw = ser.readline()
                if not raw:
                    continue
                line = raw.decode("utf-8", errors="replace")
                chunks.append(line)
                self.post("log", line)
            return "".join(chunks)
        finally:
            self._start_monitor_reader()

    def read_device(self):
        try:
            self.require_connected()
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc)); return
        def work():
            text = self._capture_with_existing_connection(max(5, self.settings.test_seconds), reset=False)
            self.last_log = text
            self.post("result", text)
        self._start("Cihaz dinleniyor...", work)

    def reset_and_read(self):
        try:
            self.require_connected()
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc)); return
        def work():
            text = self._capture_with_existing_connection(max(6, self.settings.test_seconds), reset=True)
            self.last_log = text
            self.post("result", text)
        self._start("Reset + okuma...", work)

    def run_test(self):
        try:
            self.require_connected()
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc)); return
        def work():
            text = self._capture_with_existing_connection(self.settings.test_seconds, reset=True)
            self.last_log = text
            self.post("result", text)
        self._start("Üretim testi çalışıyor...", work)

    def _show_result(self, r: TestResult):
        self.last_result = r
        self.identity_view.set(
            f"Serial: {r.serial or '—'}   HW-ID: {r.hw_id or '—'}   Schema: {r.factory_schema or '—'}   HW-Rev: {r.hw_rev or '—'}   Tarih: {r.production_date or '—'}"
        )
        self.test_labels["Identity"].set("PASS" if r.identity_ok else "FAIL")
        self.test_labels["Firmware"].set(r.firmware or "—")
        self.test_labels["SHT45"].set("PASS" if r.sensor_ok else ("BEKLİYOR" if r.unconfigured else "FAIL"))
        self.test_labels["Sıcaklık"].set((r.temperature + " °C") if r.temperature else "—")
        self.test_labels["Nem"].set((r.humidity + " %") if r.humidity else "—")
        self.test_labels["Çiy"].set((r.dew_point + " °C") if r.dew_point else "—")
        if r.battery_status:
            self.test_labels["Batarya"].set(f"{r.battery_status} {r.battery_voltage}V".strip())
        else:
            self.test_labels["Batarya"].set("—")
        self.test_labels["Şarj"].set(r.charging or "—")
        self.test_labels["OIM3"].set(r.oim3 or "—")
        self.global_status.config(text=f"Test sonucu: {r.overall}")

    def save_report(self):
        try:
            self.require_connected()
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc)); return
        r = self.last_result
        if not (r.serial or r.hw_id or r.firmware):
            messagebox.showwarning(APP_NAME, "Önce cihaz testi/okuması yapın.")
            return
        path = Path(self.settings.report_csv)
        path.parent.mkdir(parents=True, exist_ok=True)
        fields = ["timestamp", "serial", "hw_id", "hw_rev", "production_date", "factory_schema", "provisioning_secret", "qr_payload", "firmware", "identity_ok", "sensor_init", "sht45_ok", "temperature_c", "humidity_pct", "dew_point_c", "battery_status", "battery_voltage_v", "charging", "wifi", "oim3", "overall"]
        row = {
            "timestamp": datetime.now().isoformat(timespec="seconds"), "serial": r.serial, "hw_id": r.hw_id,
            "hw_rev": r.hw_rev, "production_date": r.production_date, "factory_schema": r.factory_schema, "provisioning_secret": self.prov_secret_var.get().strip(),
            "qr_payload": provisioning_qr_payload(r.serial or self.serial_var.get().strip().upper(), self.prov_secret_var.get().strip()), "firmware": r.firmware,
            "identity_ok": r.identity_ok, "sensor_init": r.sensor_init, "sht45_ok": r.sensor_ok,
            "temperature_c": r.temperature, "humidity_pct": r.humidity, "dew_point_c": r.dew_point,
            "battery_status": r.battery_status, "battery_voltage_v": r.battery_voltage,
            "charging": r.charging, "wifi": r.wifi, "oim3": r.oim3, "overall": r.overall,
        }
        exists = path.exists()
        with path.open("a", newline="", encoding="utf-8-sig") as f:
            w = csv.DictWriter(f, fieldnames=fields)
            if not exists: w.writeheader()
            w.writerow(row)
        messagebox.showinfo(APP_NAME, f"Üretim kaydı yazıldı:\n{path}")

    def open_settings(self):
        w = tk.Toplevel(self); w.title("Ayarlar"); w.geometry("650x250"); w.transient(self); w.grab_set()
        frm = ttk.Frame(w, padding=12); frm.pack(fill="both", expand=True); frm.columnconfigure(1, weight=1)
        vars_ = {
            "flash_baud": tk.StringVar(value=str(self.settings.flash_baud)),
            "monitor_baud": tk.StringVar(value=str(self.settings.monitor_baud)),
            "test_seconds": tk.StringVar(value=str(self.settings.test_seconds)),
            "report_csv": tk.StringVar(value=self.settings.report_csv),
        }
        labels = [("flash_baud", "Flash baud"), ("monitor_baud", "Monitor baud"), ("test_seconds", "Test süresi (sn)"), ("report_csv", "Üretim CSV")]
        for i,(key,label) in enumerate(labels):
            ttk.Label(frm,text=label).grid(row=i,column=0,sticky="w",pady=5)
            ttk.Entry(frm,textvariable=vars_[key]).grid(row=i,column=1,sticky="ew",padx=8,pady=5)
        ttk.Label(frm, text="Standalone üretim sürümü: ESP-IDF, CMake, Ninja ve harici Python gerekmez.").grid(row=len(labels), column=0, columnspan=2, sticky="w", pady=(10,2))
        def save():
            try:
                self.settings.flash_baud=int(vars_["flash_baud"].get()); self.settings.monitor_baud=int(vars_["monitor_baud"].get()); self.settings.test_seconds=max(3,int(vars_["test_seconds"].get())); self.settings.report_csv=vars_["report_csv"].get().strip()
                self.settings.save(); w.destroy()
            except Exception as exc: messagebox.showerror(APP_NAME, str(exc), parent=w)
        ttk.Button(frm,text="Kaydet",command=save).grid(row=len(labels)+1,column=1,sticky="e",pady=10)

    def _on_close(self):
        try:
            if self._monitor_serial is not None:
                self._close_com_internal(reset=True, notify=False)
        except Exception:
            pass
        self.destroy()


def main():
    app = VisionSenFactoryApp()
    app.mainloop()


if __name__ == "__main__":
    main()
