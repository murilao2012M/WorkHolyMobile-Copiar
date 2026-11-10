# Gera o APK release com todos os recursos Premium liberados (somente para uso interno).
# NÃO distribua este APK: ele ignora a tela de pagamento.
# Uso: .\build_release_dev.ps1 [-Install]
param(
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

flutter build apk --release --obfuscate --split-debug-info=build\symbols --dart-define=WORKHOLY_DEV_PREMIUM=true
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$apk = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
Write-Host "APK gerado: $apk"

if ($Install) {
    adb install -r $apk
}
