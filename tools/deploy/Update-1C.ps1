# Загружает конфигурацию из src/ (текущее состояние git) в локальную базу 1С
# через 1cv8.exe DESIGNER /LoadConfigFromFiles + /UpdateDBCfg.
#
# Не запускается напрямую в обычной работе — вызывается git-хуками из
# tools/git-hooks (post-merge, post-checkout) после pull/checkout, либо вручную:
#   pwsh tools/deploy/Update-1C.ps1
#
# Требует tools/deploy/Update-1C.local.ps1 с настройками конкретной машины
# (путь к 1cv8.exe, строка подключения, пользователь/пароль) — см. .example.
#
# ВАЖНО: база не должна быть открыта в клиенте 1С в этот момент — Конфигуратору
# нужен монопольный доступ для UpdateDBCfg, иначе команда завершится ошибкой.

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$LocalConfigPath = Join-Path $PSScriptRoot "Update-1C.local.ps1"

if (-not (Test-Path $LocalConfigPath)) {
    Write-Error "Не найден $LocalConfigPath. Скопируйте Update-1C.local.ps1.example в Update-1C.local.ps1 и заполните под свою машину."
    exit 1
}

. $LocalConfigPath

if (-not (Test-Path $DesignerExe)) {
    Write-Error "1cv8.exe не найден по пути: $DesignerExe. Проверьте `$DesignerExe в Update-1C.local.ps1."
    exit 1
}

$SrcPath = Join-Path $RepoRoot "src"
$LogPath = Join-Path $env:TEMP ("1c-load-config-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

$argsList = New-Object System.Collections.Generic.List[string]
$argsList.Add("DESIGNER")
$argsList.Add($ConnectionString)
if ($IbUser) { $argsList.Add("/N$IbUser") }
if ($IbPassword) { $argsList.Add("/P$IbPassword") }
$argsList.Add("/DisableStartupDialogs")
$argsList.Add("/LoadConfigFromFiles")
$argsList.Add("`"$SrcPath`"")
$argsList.Add("/UpdateDBCfg")
$argsList.Add("/Out")
$argsList.Add("`"$LogPath`"")

Write-Host "[1C] Загружаю конфигурацию из $SrcPath ..."
$process = Start-Process -FilePath $DesignerExe -ArgumentList $argsList -Wait -PassThru -NoNewWindow

if (Test-Path $LogPath) {
    Get-Content $LogPath | Write-Host
}

if ($process.ExitCode -ne 0) {
    Write-Error "1cv8.exe завершился с кодом $($process.ExitCode). Полный лог: $LogPath"
    exit $process.ExitCode
}

Write-Host "[1C] База обновлена."
