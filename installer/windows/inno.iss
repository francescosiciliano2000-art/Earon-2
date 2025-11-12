#define MyAppName "Earon"
#define MyAppVersion "0.1.2"   ; <— aggiorna ad ogni release
#define MyExeName "Earon.exe"

[Setup]
AppId={{E3EDC4C9-3C8B-4C8C-9F7D-EE0000E1A1E1}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={pf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableDirPage=no
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename={#MyAppName}-Setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
; SetupIconFile=icon.ico
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "desktopicon"; Description: "Crea un'icona sul Desktop"; GroupDescription: "Icone:"; Flags: unchecked

[Files]
; Include only existing build output paths at compile time to avoid errors
#ifexist "..\\..\\build\\windows\\x64\\runner\\Release\\*"
Source: "..\\..\\build\\windows\\x64\\runner\\Release\\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs
#endif
#ifexist "..\\..\\build\\windows\\runner\\Release\\*"
Source: "..\\..\\build\\windows\\runner\\Release\\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs
#endif

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyExeName}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyExeName}"; Description: "Avvia {#MyAppName}"; Flags: nowait postinstall skipifsilent
