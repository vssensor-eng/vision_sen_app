from __future__ import annotations

import csv, json, os, queue, re, secrets, subprocess, threading, time
from dataclasses import dataclass, asdict
from datetime import date, datetime
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

import serial
from serial.tools import list_ports

APP_NAME = "VisionSen Factory PC Tool"
APP_VERSION = "0.2.0"
SERIAL_RE = re.compile(r"^ESP-[0-9]{1,13}$")
SECRET_RE = re.compile(r"^[A-Za-z0-9]{16,32}$")
ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
VSFACT_RE = re.compile(r"VSFACT1\s+(.*)$")

APPDATA = Path(os.getenv("LOCALAPPDATA") or Path.home()) / "VisionSen" / "FactoryTool"
APPDATA.mkdir(parents=True, exist_ok=True)
CONFIG_FILE = APPDATA / "settings.json"
DEFAULT_REPORT = APPDATA / "production_records.csv"


@dataclass
class Settings:
    idf_python: str = r"C:\Espressif\tools\python\v6.1\venv\Scripts\python.exe"
    idf_path: str = r"C:\esp\v6.1\esp-idf"
    firmware_project: str = r"C:\ESP32\workspace\visionsen_oim3_idf_v2_1_6_factory_qa"
    flash_baud: int = 460800
    monitor_baud: int = 115200
    test_seconds: int = 10
    report_csv: str = str(DEFAULT_REPORT)

    @classmethod
    def load(cls):
        try:
            data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
            base = asdict(cls())
            base.update({k: v for k, v in data.items() if k in base})
            return cls(**base)
        except Exception:
            return cls()

    def save(self):
        CONFIG_FILE.write_text(json.dumps(asdict(self), indent=2, ensure_ascii=False), encoding="utf-8")


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f"{APP_NAME} v{APP_VERSION}")
        self.geometry("1180x780")
        self.minsize(1030, 700)
        self.settings = Settings.load()
        self.msgq = queue.Queue()
        self.busy = False
        self.last = {}
        self.last_log = ""
        self._style()
        self._ui()
        self.refresh_ports()
        self.after(100, self._drain)

    def _style(self):
        self.configure(bg="#0f172a")
        s = ttk.Style(self)
        try: s.theme_use("clam")
        except Exception: pass
        s.configure("TFrame", background="#0f172a")
        s.configure("TLabelframe", background="#111827", foreground="#e5e7eb")
        s.configure("TLabelframe.Label", background="#111827", foreground="#e5e7eb", font=("Segoe UI", 10, "bold"))
        s.configure("TLabel", background="#0f172a", foreground="#e5e7eb", font=("Segoe UI", 9))
        s.configure("Title.TLabel", font=("Segoe UI", 18, "bold"), foreground="#f8fafc")
        s.configure("Status.TLabel", font=("Segoe UI", 10, "bold"), foreground="#93c5fd")
        s.configure("TButton", font=("Segoe UI", 9, "bold"), padding=6)
        s.configure("TCheckbutton", background="#111827", foreground="#e5e7eb")

    def _ui(self):
        root = ttk.Frame(self, padding=14); root.pack(fill="both", expand=True)
        root.columnconfigure(0, weight=1); root.rowconfigure(4, weight=1)
        head = ttk.Frame(root); head.grid(row=0, column=0, sticky="ew", pady=(0,10))
        ttk.Label(head, text="VisionSen Üretim ve Kalite Kontrol", style="Title.TLabel").pack(side="left")
        self.status = ttk.Label(head, text="Hazır", style="Status.TLabel"); self.status.pack(side="right")

        c = ttk.LabelFrame(root, text="1. Cihaz bağlantısı / firmware", padding=10); c.grid(row=1, column=0, sticky="ew", pady=4)
        c.columnconfigure(1, weight=1); c.columnconfigure(4, weight=2)
        ttk.Label(c, text="COM").grid(row=0,column=0,sticky="w")
        self.port = tk.StringVar(); self.port_box = ttk.Combobox(c,textvariable=self.port,state="readonly",width=16); self.port_box.grid(row=0,column=1,sticky="ew",padx=6)
        ttk.Button(c,text="Yenile",command=self.refresh_ports).grid(row=0,column=2,padx=4)
        ttk.Button(c,text="Firmware Yükle",command=self.flash).grid(row=0,column=3,padx=4)
        ttk.Button(c,text="Build + Yükle",command=self.build_flash).grid(row=0,column=4,padx=4,sticky="w")
        ttk.Label(c,text="Firmware proje klasörü").grid(row=1,column=0,sticky="w",pady=(8,0))
        self.project = tk.StringVar(value=self.settings.firmware_project); ttk.Entry(c,textvariable=self.project).grid(row=1,column=1,columnspan=3,sticky="ew",padx=6,pady=(8,0))
        ttk.Button(c,text="Seç",command=self.select_project).grid(row=1,column=4,sticky="w",padx=4,pady=(8,0))

        f = ttk.LabelFrame(root,text="2. Factory Identity (schema v2)",padding=10); f.grid(row=2,column=0,sticky="ew",pady=4)
        for i in (1,3,5): f.columnconfigure(i,weight=1)
        self.serial_no=tk.StringVar(value="ESP-001"); self.hwrev=tk.StringVar(value="OIM3-R1"); self.prod=tk.StringVar(value=date.today().isoformat()); self.secret=tk.StringVar(value=self.new_secret())
        ttk.Label(f,text="Seri No").grid(row=0,column=0,sticky="w"); ttk.Entry(f,textvariable=self.serial_no).grid(row=0,column=1,sticky="ew",padx=5)
        ttk.Label(f,text="HW Rev").grid(row=0,column=2,sticky="w"); ttk.Entry(f,textvariable=self.hwrev).grid(row=0,column=3,sticky="ew",padx=5)
        ttk.Label(f,text="Üretim Tarihi").grid(row=0,column=4,sticky="w"); ttk.Entry(f,textvariable=self.prod).grid(row=0,column=5,sticky="ew",padx=5)
        ttk.Button(f,text="Kimliği Yaz / Güncelle",command=self.write_identity).grid(row=0,column=6,padx=4)
        ttk.Label(f,text="Cihaz Kurulum Kodu").grid(row=1,column=0,sticky="w",pady=(8,0)); ttk.Entry(f,textvariable=self.secret).grid(row=1,column=1,columnspan=2,sticky="ew",padx=5,pady=(8,0))
        ttk.Button(f,text="Yeni Kod",command=lambda:self.secret.set(self.new_secret())).grid(row=1,column=3,padx=4,pady=(8,0)); ttk.Button(f,text="Kopyala",command=self.copy_secret).grid(row=1,column=4,padx=4,pady=(8,0))
        self.clear_storage=tk.BooleanVar(value=True); ttk.Checkbutton(f,text="Kimlik yeniden atanıyorsa storage/queue temizle",variable=self.clear_storage).grid(row=1,column=5,columnspan=2,sticky="w",pady=(8,0))
        self.identity=tk.StringVar(value="Cihaz kimliği henüz okunmadı"); ttk.Label(f,textvariable=self.identity).grid(row=2,column=0,columnspan=5,sticky="w",pady=(8,0))
        ttk.Button(f,text="Reset + Oku",command=self.read_test).grid(row=2,column=5,padx=4,pady=(8,0)); ttk.Button(f,text="Üretim Testi",command=self.read_test).grid(row=2,column=6,padx=4,pady=(8,0))

        t = ttk.LabelFrame(root,text="3. Test sonucu",padding=10); t.grid(row=3,column=0,sticky="ew",pady=4)
        self.testvars={}
        for i,name in enumerate(["Identity","Firmware","SHT45","Sıcaklık","Nem","Çiy","Batarya","Şarj"]):
            box=ttk.Frame(t,padding=5); box.grid(row=0,column=i,sticky="nsew"); t.columnconfigure(i,weight=1)
            ttk.Label(box,text=name,font=("Segoe UI",9,"bold")).pack(); v=tk.StringVar(value="—"); ttk.Label(box,textvariable=v).pack(); self.testvars[name]=v
        ttk.Button(t,text="CSV Kaydet",command=self.save_csv).grid(row=1,column=0,padx=4,pady=(8,0),sticky="w")
        ttk.Label(t,text="v2.1.6 Factory QA / VSFACT1: Wi‑Fi kurulumu yapılmadan sensör ve güç testi yapılabilir.").grid(row=1,column=1,columnspan=7,sticky="w",pady=(8,0))

        lg=ttk.LabelFrame(root,text="İşlem / cihaz logu",padding=6); lg.grid(row=4,column=0,sticky="nsew",pady=4); lg.rowconfigure(0,weight=1); lg.columnconfigure(0,weight=1)
        self.log=tk.Text(lg,wrap="none",font=("Consolas",9),bg="#020617",fg="#d1fae5",insertbackground="white"); self.log.grid(row=0,column=0,sticky="nsew")
        sy=ttk.Scrollbar(lg,orient="vertical",command=self.log.yview); sy.grid(row=0,column=1,sticky="ns"); self.log.configure(yscrollcommand=sy.set)
        foot=ttk.Frame(root); foot.grid(row=5,column=0,sticky="ew",pady=(5,0)); ttk.Button(foot,text="Ayarlar",command=self.settings_dialog).pack(side="left"); ttk.Button(foot,text="Logu Temizle",command=lambda:self.log.delete("1.0","end")).pack(side="left",padx=6); ttk.Label(foot,text=f"v{APP_VERSION}").pack(side="right")

    @staticmethod
    def new_secret(n=20): return "".join(secrets.choice(ALPHABET) for _ in range(n))
    def copy_secret(self): self.clipboard_clear(); self.clipboard_append(self.secret.get().strip()); self.status.config(text="Kurulum kodu panoya kopyalandı")
    def refresh_ports(self):
        vals=[p.device for p in list_ports.comports()]; self.port_box["values"]=vals
        if vals and self.port.get() not in vals: self.port.set(vals[0])
        self.status.config(text=f"{len(vals)} COM port bulundu" if vals else "COM port bulunamadı")
    def select_project(self):
        p=filedialog.askdirectory(initialdir=self.project.get() or None)
        if p: self.project.set(p); self.settings.firmware_project=p; self.settings.save()
    def require_port(self):
        if not self.port.get().strip(): raise RuntimeError("COM port seçin.")
        return self.port.get().strip()
    def require_project(self):
        p=Path(self.project.get().strip())
        if not p.is_dir(): raise RuntimeError("Firmware proje klasörü bulunamadı.")
        return p
    def py(self):
        p=Path(self.settings.idf_python)
        if not p.is_file(): raise RuntimeError(f"ESP-IDF Python bulunamadı: {p}")
        return p
    def idf(self):
        p=Path(self.settings.idf_path)/"tools"/"idf.py"
        if not p.is_file(): raise RuntimeError(f"idf.py bulunamadı: {p}")
        return p
    def env(self):
        e=os.environ.copy(); e["IDF_PATH"]=self.settings.idf_path; return e
    def post(self,k,v): self.msgq.put((k,v))
    def _drain(self):
        try:
            while True:
                k,v=self.msgq.get_nowait()
                if k=="log": self.log.insert("end",v); self.log.see("end")
                elif k=="status": self.status.config(text=v)
                elif k=="result": self.show_result(v)
                elif k=="error": self.busy=False; self.status.config(text="Hata"); messagebox.showerror(APP_NAME,v)
                elif k=="done": self.busy=False; self.status.config(text=v or "Hazır")
        except queue.Empty: pass
        self.after(100,self._drain)
    def start(self,label,fn):
        if self.busy: messagebox.showwarning(APP_NAME,"Başka bir işlem devam ediyor."); return
        self.busy=True; self.status.config(text=label); threading.Thread(target=self._run,args=(fn,),daemon=True).start()
    def _run(self,fn):
        try: fn(); self.post("done","Hazır")
        except Exception as ex: self.post("error",str(ex))
    def cmd(self,args,cwd=None):
        self.post("log","\n> "+subprocess.list2cmdline([str(x) for x in args])+"\n")
        p=subprocess.Popen([str(x) for x in args],cwd=str(cwd) if cwd else None,env=self.env(),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding="utf-8",errors="replace")
        for line in p.stdout or []: self.post("log",line)
        if p.wait()!=0: raise RuntimeError(f"Komut başarısız oldu (exit={p.returncode}).")
    def flash(self): self.start("Firmware yükleniyor...",lambda:self.cmd([self.py(),self.idf(),"-p",self.require_port(),"-b",str(self.settings.flash_baud),"flash"],self.require_project()))
    def build_flash(self): self.start("Build + flash...",lambda:self.cmd([self.py(),self.idf(),"-p",self.require_port(),"-b",str(self.settings.flash_baud),"build","flash"],self.require_project()))
    def write_identity(self):
        s=self.serial_no.get().strip().upper(); sec=self.secret.get().strip(); pd=self.prod.get().strip()
        if not SERIAL_RE.fullmatch(s): messagebox.showerror(APP_NAME,"Seri no ESP-<rakamlar> formatında olmalı."); return
        if not SECRET_RE.fullmatch(sec): messagebox.showerror(APP_NAME,"Kurulum kodu 16-32 harf/rakam olmalı."); return
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}",pd): messagebox.showerror(APP_NAME,"Üretim tarihi YYYY-MM-DD olmalı."); return
        if not messagebox.askyesno(APP_NAME,f"{s} factory identity yazılsın/güncellensin mi?"): return
        def work():
            pr=self.require_project(); tool=pr/"tools"/"factory_serial.py"
            if not tool.is_file(): raise RuntimeError(f"factory_serial.py bulunamadı: {tool}")
            a=[self.py(),tool,"write","--port",self.require_port(),"--baud",str(self.settings.flash_baud),"--serial",s,"--hw-rev",self.hwrev.get().strip(),"--production-date",pd,"--provision-secret",sec,"--yes"]
            if self.clear_storage.get(): a.append("--clear-storage")
            self.cmd(a,pr); self.post("status","Factory identity PASS")
        self.start("Factory identity yazılıyor...",work)
    def hard_reset(self,p): self.cmd([self.py(),"-m","esptool","--chip","esp32","--port",p,"chip-id"]); time.sleep(.5)
    def capture(self,p,seconds):
        end=time.monotonic()+seconds; out=[]; ser=None; last=None
        while time.monotonic()<end and ser is None:
            try: ser=serial.Serial(p,self.settings.monitor_baud,timeout=.15)
            except Exception as ex: last=ex; time.sleep(.2)
        if ser is None: raise RuntimeError(f"Seri port açılamadı: {last}")
        with ser:
            while time.monotonic()<end:
                b=ser.readline()
                if b:
                    line=b.decode("utf-8",errors="replace"); out.append(line); self.post("log",line)
        return "".join(out)
    def read_test(self):
        def work():
            p=self.require_port(); self.hard_reset(p); text=self.capture(p,self.settings.test_seconds); self.last_log=text; self.post("result",text)
        self.start("Üretim testi...",work)
    def parse(self,text):
        d={"serial":"","hw_id":"","fw":"","schema":"","sensor_init":"","sht45":"","temp_c":"","humidity_pct":"","dew_point_c":"","battery_status":"","battery_v":"","charging":""}
        for line in text.splitlines():
            m=VSFACT_RE.search(line)
            if m:
                for token in m.group(1).split():
                    if "=" in token:
                        k,v=token.split("=",1); d[k]=v
            if not d["fw"]:
                m=re.search(r"Firmware\s*:\s*([0-9.]+)",line)
                if m: d["fw"]=m.group(1)
            if not d["serial"]:
                m=re.search(r"Factory identity: serial=(\S+) hw_id=(\S+)",line)
                if m: d["serial"],d["hw_id"]=m.group(1),m.group(2)
        return d
    def show_result(self,text):
        d=self.parse(text); self.last=d
        identity_ok=bool(SERIAL_RE.fullmatch(d["serial"])) and bool(d["hw_id"]) and d["schema"]=="2"
        sensor_ok=d["sensor_init"]=="OK" and d["sht45"]=="PASS" and d["temp_c"] not in ("","NA") and d["humidity_pct"] not in ("","NA")
        self.identity.set(f"Serial: {d['serial'] or '—'}   HW-ID: {d['hw_id'] or '—'}   Schema: {d['schema'] or '—'}")
        self.testvars["Identity"].set("PASS" if identity_ok else "FAIL"); self.testvars["Firmware"].set(d["fw"] or "—"); self.testvars["SHT45"].set("PASS" if sensor_ok else "FAIL")
        self.testvars["Sıcaklık"].set((d["temp_c"]+" °C") if d["temp_c"] not in ("","NA") else "—"); self.testvars["Nem"].set((d["humidity_pct"]+" %") if d["humidity_pct"] not in ("","NA") else "—"); self.testvars["Çiy"].set((d["dew_point_c"]+" °C") if d["dew_point_c"] not in ("","NA") else "—")
        self.testvars["Batarya"].set((d["battery_status"]+" "+d["battery_v"]+"V").strip() if d["battery_status"] else "—"); self.testvars["Şarj"].set(d["charging"] or "—")
        result="PASS" if identity_ok and sensor_ok else "FAIL"
        if result=="PASS" and d["battery_status"] not in ("","OK"): result="PASS + BATTERY WARNING"
        self.status.config(text="Test sonucu: "+result)
    def save_csv(self):
        if not self.last: messagebox.showwarning(APP_NAME,"Önce üretim testi yapın."); return
        p=Path(self.settings.report_csv); p.parent.mkdir(parents=True,exist_ok=True); exists=p.exists()
        fields=["timestamp","serial","hw_id","schema","firmware","provisioning_secret","sensor_init","sht45","temp_c","humidity_pct","dew_point_c","battery_status","battery_v","charging"]
        row={"timestamp":datetime.now().isoformat(timespec="seconds"),"provisioning_secret":self.secret.get().strip(),**{k:self.last.get(k,"") for k in fields if k not in ("timestamp","provisioning_secret")}}
        with p.open("a",newline="",encoding="utf-8-sig") as fh:
            w=csv.DictWriter(fh,fieldnames=fields)
            if not exists: w.writeheader()
            w.writerow(row)
        messagebox.showinfo(APP_NAME,f"Üretim kaydı yazıldı:\n{p}")
    def settings_dialog(self):
        w=tk.Toplevel(self); w.title("Ayarlar"); w.geometry("780x360"); w.transient(self); w.grab_set(); f=ttk.Frame(w,padding=12); f.pack(fill="both",expand=True); f.columnconfigure(1,weight=1)
        vals={"idf_python":tk.StringVar(value=self.settings.idf_python),"idf_path":tk.StringVar(value=self.settings.idf_path),"firmware_project":tk.StringVar(value=self.project.get()),"flash_baud":tk.StringVar(value=str(self.settings.flash_baud)),"monitor_baud":tk.StringVar(value=str(self.settings.monitor_baud)),"test_seconds":tk.StringVar(value=str(self.settings.test_seconds)),"report_csv":tk.StringVar(value=self.settings.report_csv)}
        for i,(k,label) in enumerate([("idf_python","ESP-IDF Python"),("idf_path","IDF_PATH"),("firmware_project","Firmware proje"),("flash_baud","Flash baud"),("monitor_baud","Monitor baud"),("test_seconds","Test süresi (sn)"),("report_csv","Üretim CSV")]):
            ttk.Label(f,text=label).grid(row=i,column=0,sticky="w",pady=5); ttk.Entry(f,textvariable=vals[k]).grid(row=i,column=1,sticky="ew",padx=8,pady=5)
        def save():
            try:
                self.settings.idf_python=vals["idf_python"].get().strip(); self.settings.idf_path=vals["idf_path"].get().strip(); self.settings.firmware_project=vals["firmware_project"].get().strip(); self.settings.flash_baud=int(vals["flash_baud"].get()); self.settings.monitor_baud=int(vals["monitor_baud"].get()); self.settings.test_seconds=max(3,int(vals["test_seconds"].get())); self.settings.report_csv=vals["report_csv"].get().strip(); self.settings.save(); self.project.set(self.settings.firmware_project); w.destroy()
            except Exception as ex: messagebox.showerror(APP_NAME,str(ex),parent=w)
        ttk.Button(f,text="Kaydet",command=save).grid(row=7,column=1,sticky="e",pady=10)

if __name__ == "__main__": App().mainloop()
