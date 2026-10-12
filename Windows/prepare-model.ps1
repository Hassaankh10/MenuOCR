$ErrorActionPreference = 'Stop'
$path = Join-Path $PSScriptRoot 'App/tessdata/eng.traineddata'
$expected = '7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2'
New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
if (!(Test-Path $path) -or (Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
    Invoke-WebRequest 'https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/65727574dfcd264acbb0c3e07860e4e9e9b22185/eng.traineddata' -OutFile $path
}
if ((Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) { throw 'English OCR model checksum mismatch.' }
