# Gera o APK/AAB de produção (Premium validado, sem bypass de desenvolvimento).
# Guarde build\symbols fora do repositório: é necessário para ler stack traces.
# Uso: .\build_release_producao.ps1 [-Bundle]
param(
    [switch]$Bundle
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Test-Path 'android\key.properties')) {
    throw 'android\key.properties ausente: o release precisa ser assinado com a chave de produção.'
}

$alvo = if ($Bundle) { 'appbundle' } else { 'apk' }
flutter build $alvo --release --obfuscate --split-debug-info=build\symbols
exit $LASTEXITCODE
