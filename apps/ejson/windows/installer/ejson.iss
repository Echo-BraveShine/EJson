[Setup]
AppId=dev.ekko.ejson
AppName=EJson
AppVersion={#AppVersion}
VersionInfoVersion={#AppVersion}.{#BuildNumber}
VersionInfoProductTextVersion={#AppVersion}+{#BuildNumber}
AppPublisher=EJson
DefaultDirName={localappdata}\Programs\EJson
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\ejson.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableWelcomePage=no
WizardImageFile=wizard-sidebar.bmp
WizardImageStretch=yes
ChangesAssociations=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\EJson"; Filename: "{app}\ejson.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\ejson.exe"; Description: "{cm:LaunchProgram,EJson}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent

[Registry]
Root: HKCU; Subkey: "Software\Classes\.json\OpenWithProgids"; ValueType: string; ValueName: "EJson.Json"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\EJson.Json"; ValueType: string; ValueData: "JSON document"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\EJson.Json\DefaultIcon"; ValueType: string; ValueData: "{app}\ejson.exe,0"
Root: HKCU; Subkey: "Software\Classes\EJson.Json\shell\open\command"; ValueType: string; ValueData: """{app}\ejson.exe"" ""%1"""

Root: HKCU; Subkey: "Software\Classes\.jsonl\OpenWithProgids"; ValueType: string; ValueName: "EJson.Document"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.ndjson\OpenWithProgids"; ValueType: string; ValueName: "EJson.Document"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.xml\OpenWithProgids"; ValueType: string; ValueName: "EJson.Document"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.csv\OpenWithProgids"; ValueType: string; ValueName: "EJson.Document"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.yaml\OpenWithProgids"; ValueType: string; ValueName: "EJson.Document"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.yml\OpenWithProgids"; ValueType: string; ValueName: "EJson.Document"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.toml\OpenWithProgids"; ValueType: string; ValueName: "EJson.Document"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\EJson.Document"; ValueType: string; ValueData: "Structured data document"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\EJson.Document\DefaultIcon"; ValueType: string; ValueData: "{app}\ejson.exe,0"
Root: HKCU; Subkey: "Software\Classes\EJson.Document\shell\open\command"; ValueType: string; ValueData: """{app}\ejson.exe"" ""%1"""
