#define MyAppName "Earon"
#define MyAppVersion "0.1.2"   ; <— aggiorna ad ogni release
#define MyExeName "Earon.exe"
; Percorso di build: forziamo quello x64 (coerente con workflow e rename a Earon.exe)
#define BuildDir "..\\..\\build\\windows\\x64\\runner\\Release"

[Setup]
AppId={{E3EDC4C9-3C8B-4C8C-9F7D-EE0000E1A1E1}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
; Forza installazione a 64 bit e posizione corretta su sistemi x64
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
DefaultDirName={pf64}\{#MyAppName}
UsePreviousAppDir=no
DefaultGroupName={#MyAppName}
DisableDirPage=no
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename={#MyAppName}-Setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
; SetupIconFile=icon.ico
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "desktopicon"; Description: "Crea un'icona sul Desktop"; GroupDescription: "Icone:"; Flags: unchecked

[Files]
; Copia tutto dalla cartella di build selezionata
Source: "{#BuildDir}\\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs
; Copia esplicita dell’eseguibile (rename a Earon.exe se necessario)
#ifexist "{#BuildDir}\\Earon.exe"
Source: "{#BuildDir}\\Earon.exe"; DestDir: "{app}"; DestName: "{#MyExeName}"; Flags: ignoreversion
#endif
#ifexist "{#BuildDir}\\gestionale_desktop.exe"
Source: "{#BuildDir}\\gestionale_desktop.exe"; DestDir: "{app}"; DestName: "{#MyExeName}"; Flags: ignoreversion
#endif

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyExeName}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyExeName}"; Tasks: desktopicon

[Run]
; Avvia l'app solo se l'eseguibile è presente. Nota: in espressioni di Check, le stringhe devono usare apici singoli.
Filename: "{app}\{#MyExeName}"; Description: "Avvia {#MyAppName}"; Flags: nowait postinstall skipifsilent; Check: FileExists(ExpandConstant('{app}\{#MyExeName}'))
