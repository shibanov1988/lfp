# Dumps the current local database configuration into src/ (git working
# tree) via 1cv8.exe DESIGNER /DumpConfigToFiles - the reverse of
# Update-1C.ps1, used before committing local Designer changes to git.
#
# Called by push.bat (repo root), or run manually:
#   powershell -File tools/deploy/Dump-1C.ps1
#
# Reuses the same tools/deploy/Update-1C.local.txt as Update-1C.ps1 - no
# separate setup needed if that already works.
#
# Unlike /UpdateDBCfg, dumping does not need exclusive access - it is safe
# to run with the 1C client open, as long as no other Designer session is
# connected to the same base.

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$LocalConfigPath = Join-Path $PSScriptRoot "Update-1C.local.txt"

if (-not (Test-Path $LocalConfigPath)) {
    Write-Error "Not found: $LocalConfigPath. Copy Update-1C.local.example.txt to Update-1C.local.txt next to it and fill it in for your machine."
    exit 1
}

# Read explicitly as UTF-8 so Cyrillic values (e.g. in the infobase path)
# decode correctly regardless of whether the file was saved with a BOM.
$Config = @{}
Get-Content -LiteralPath $LocalConfigPath -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $idx = $line.IndexOf("=")
    if ($idx -lt 0) { return }
    $key = $line.Substring(0, $idx).Trim()
    $value = $line.Substring($idx + 1)
    $Config[$key] = $value
}

$DesignerExe = $Config["DesignerExe"]
$ConnectionString = $Config["ConnectionString"]
$IbUser = $Config["IbUser"]
$IbPassword = $Config["IbPassword"]

if (-not $DesignerExe -or -not $ConnectionString) {
    Write-Error "DesignerExe and ConnectionString must both be set in $LocalConfigPath"
    exit 1
}

if (-not (Test-Path $DesignerExe)) {
    Write-Error "1cv8.exe not found at: $DesignerExe. Check DesignerExe in $LocalConfigPath."
    exit 1
}

$SrcPath = Join-Path $RepoRoot "src"
$LogPath = Join-Path $env:TEMP ("1c-dump-config-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

$argsList = New-Object System.Collections.Generic.List[string]
$argsList.Add("DESIGNER")
$argsList.Add($ConnectionString)
if ($IbUser) { $argsList.Add("/N$IbUser") }
if ($IbPassword) { $argsList.Add("/P$IbPassword") }
$argsList.Add("/DisableStartupDialogs")
$argsList.Add("/DumpConfigToFiles")
$argsList.Add("`"$SrcPath`"")
$argsList.Add("/Out")
$argsList.Add("`"$LogPath`"")

Write-Host "[1C] Dumping configuration to $SrcPath ..."
$process = Start-Process -FilePath $DesignerExe -ArgumentList $argsList -Wait -PassThru -NoNewWindow

if (Test-Path $LogPath) {
    Get-Content -LiteralPath $LogPath | Write-Host
}

if ($process.ExitCode -ne 0) {
    Write-Error "1cv8.exe exited with code $($process.ExitCode). Full log: $LogPath"
    exit $process.ExitCode
}

Write-Host "[1C] Configuration dumped to src/."
