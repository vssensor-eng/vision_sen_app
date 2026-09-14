#define MyAppName "VisionSen Factory Tool"
#define MyAppVersion "0.2.0"
#define MyAppExeName "VisionSen-Factory-Tool.exe"

[Setup]
AppId={{A5C09E12-7F59-4B86-B739-1BEBF2A9E8D1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=VisionSen
DefaultDirName={localappdata}\Programs\VisionSen\Factory Tool
DefaultGroupName=VisionSen
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=installer_out
OutputBaseFilename=VisionSen-Factory-PC-Tool-v0.2.0-Setup
SetupIconFile=assets\visionsen_factory.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible

[Files]
Source: "dist\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{group}\VisionSen Factory Tool'u Kaldır"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{#MyAppName} uygulamasını başlat"; Flags: nowait postinstall skipifsilent
