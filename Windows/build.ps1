param([switch]$SkipInstaller)
$ErrorActionPreference = 'Stop'
& "$PSScriptRoot/prepare-model.ps1"
$dist = Join-Path $PSScriptRoot 'dist'
$app = Join-Path $dist 'app'
if (Test-Path $app) { Remove-Item $app -Recurse -Force }
dotnet publish "$PSScriptRoot/App/MenuOCR.Windows.csproj" -c Release -r win-x64 --self-contained true -o $app
if ($LASTEXITCODE -ne 0) { throw 'Application publish failed.' }
foreach ($file in @('MenuOCR.exe', 'tessdata/eng.traineddata', 'x64/tesseract50.dll', 'x64/leptonica-1.82.0.dll')) {
    if (!(Test-Path (Join-Path $app $file))) { throw "Missing runtime file: $file" }
}
Compress-Archive -Path "$app/*" -DestinationPath "$dist/MenuOCR-Windows-x64-1.1.1.zip" -Force
if (!$SkipInstaller) {
    $redist = Join-Path $dist 'vc_redist.x64.exe'
    Invoke-WebRequest 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile $redist
    $signature = Get-AuthenticodeSignature $redist
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') { throw 'Visual C++ runtime signature verification failed.' }
    $iscc = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source
    if (!$iscc) { $iscc = "${env:ProgramFiles(x86)}/Inno Setup 6/ISCC.exe" }
    & $iscc "$PSScriptRoot/Installer/MenuOCR.iss"
    if ($LASTEXITCODE -ne 0) { throw 'Installer build failed.' }
}
