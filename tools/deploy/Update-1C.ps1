# Loads the configuration from src/ (current git state) into the local 1C
# database via 1cv8.exe DESIGNER /LoadConfigFromFiles + /UpdateDBCfg.
#
# Not meant to be run directly in normal work - it is called by the git
# hooks in tools/git-hooks (post-merge, post-checkout) after pull/checkout,
# or you can run it manually:
#   powershell -File tools/deploy/Update-1C.ps1
#
# Requires tools/deploy/Update-1C.local.txt with machine-specific settings
# (path to 1cv8.exe, connection string, user/password) - see the
# .example.txt file next to it.
#
# IMPORTANT: the database must be closed in the 1C client at this moment -
# the Designer needs exclusive access for /UpdateDBCfg, otherwise it fails.

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

Write-Host "[1C] Loading configuration from $SrcPath ..."
$process = Start-Process -FilePath $DesignerExe -ArgumentList $argsList -Wait -PassThru -NoNewWindow

if (Test-Path $LogPath) {
    Get-Content -LiteralPath $LogPath | Write-Host
}

if ($process.ExitCode -ne 0) {
    Write-Error "1cv8.exe exited with code $($process.ExitCode). Full log: $LogPath"
    exit $process.ExitCode
}

Write-Host "[1C] Database updated."
