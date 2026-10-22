# MenuOCR for Windows

Windows 10/11, x64. Runs in the system tray after first-launch setup.

Press **Ctrl + Shift + O**, select text, then paste with **Ctrl + V**.
A confirmation appears at the bottom center of the selected screen, with **Copy formatted** and **Copy plain text** buttons. It closes after three seconds, even while hovered.

Re-copy the last result with **Ctrl + Alt + Shift + C** (formatted) or
**Ctrl + Alt + Shift + V** (plain). Change all three shortcuts in Settings.
Formatted copying preserves readable paragraphs, indentation and approximate
text sizes, with a plain-text fallback. Original fonts and styling are not reconstructed.
Change the shortcut or reopen setup from the tray menu.

Select a QR code with the same shortcut to copy its contents. QR content takes
priority over OCR when codes are present. Multiple distinct codes are separated
by newlines; links are copied without being opened.

## Install

Download the Windows Setup EXE from [Releases](https://github.com/Hassaankh10/MenuOCR/releases).
The installer includes Tesseract, English OCR data and the .NET runtime.
It installs the Microsoft Visual C++ x64 runtime if needed; that step may ask
for administrator permission. The app itself runs as your user.

For the portable ZIP, extract all files together and open `MenuOCR.exe`.
Install the [Visual C++ x64 runtime](https://aka.ms/vs/17/release/vc_redist.x64.exe) if needed.
These builds are unsigned; Windows may show a SmartScreen warning.

## Build

Install the [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
and [Inno Setup 6](https://jrsoftware.org/isdl.php) on Windows, then run in PowerShell:

```powershell
./Windows/build.ps1
```

The ZIP and installer are in `Windows/dist`. Use `-SkipInstaller` to build only the ZIP.

## Languages

English is included. Choose **Open languages folder** from the tray menu and
add compatible `.traineddata` files from [tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast).
MenuOCR compares all installed models and selects the highest text-weighted
confidence. This is a heuristic; short or mixed-language text may be misidentified.
More languages take longer. Cancel stops after the current model finishes.

OCR stays on your computer. Windows does not require macOS-style Screen Recording
or Accessibility permissions. Protected content and secure desktops cannot be captured.
The tray menu also lets you copy the last screenshot image.

## Checks

```powershell
dotnet run --project Windows/CoreChecks
./Windows/prepare-model.ps1
dotnet run --project Windows/NativeSmoke -- "$PWD/Windows/App/tessdata"
```

GitHub Actions runs these checks and builds Windows packages. The checks cover OCR, QR decoding, clipboard formats, popup timing and shortcuts.
