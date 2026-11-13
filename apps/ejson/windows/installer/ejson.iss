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

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\EJson"; Filename: "{app}\ejson.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\ejson.exe"; Description: "{cm:LaunchProgram,EJson}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent
