[Setup]
AppId={{4FF3B7C4-67CF-4A8A-9D52-578D11DFF017}
AppName=MenuOCR
AppVersion=1.0.0
AppPublisher=Hassaankh10
AppPublisherURL=https://github.com/Hassaankh10/MenuOCR
DefaultDirName={localappdata}\Programs\MenuOCR
DefaultGroupName=MenuOCR
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\dist
OutputBaseFilename=MenuOCR-Windows-x64-1.0.0-Setup
SetupIconFile=..\App\Assets\MenuOCR.ico
UninstallDisplayIcon={app}\MenuOCR.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked
[Files]
Source: "..\dist\app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\dist\vc_redist.x64.exe"; Flags: dontcopy
[Icons]
Name: "{group}\MenuOCR"; Filename: "{app}\MenuOCR.exe"
Name: "{autodesktop}\MenuOCR"; Filename: "{app}\MenuOCR.exe"; Tasks: desktopicon
[Run]
Filename: "{app}\MenuOCR.exe"; Description: "Open MenuOCR"; Flags: nowait postinstall skipifsilent
[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
var Installed: Cardinal; ExitCode: Integer;
begin
  Result := '';
  if RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed) and (Installed = 1) then Exit;
  ExtractTemporaryFile('vc_redist.x64.exe');
  if not ShellExec('runas', ExpandConstant('{tmp}\vc_redist.x64.exe'), '/install /passive /norestart', '', SW_SHOW, ewWaitUntilTerminated, ExitCode) then
    Result := 'MenuOCR needs the Microsoft Visual C++ x64 runtime. Allow its installation, then retry.'
  else if (ExitCode <> 0) and (ExitCode <> 3010) then
    Result := 'Visual C++ runtime installation failed (code ' + IntToStr(ExitCode) + '). Install it from Microsoft, then retry.'
  else NeedsRestart := ExitCode = 3010;
end;
