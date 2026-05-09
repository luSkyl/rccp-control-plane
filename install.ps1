[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$TargetRoot = (Get-Location).Path,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$sourceRoot = $PSScriptRoot
$target = Resolve-Path -LiteralPath $TargetRoot
$targetPath = $target.Path

$rccpDir = Join-Path $targetPath ".rccp"
if ((Test-Path -LiteralPath $rccpDir) -and -not $Force) {
    throw ".rccp already exists in $targetPath. Re-run with -Force to refresh."
}

New-Item -ItemType Directory -Force -Path $rccpDir | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceRoot "scripts") -Destination $rccpDir -Recurse -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot "policies") -Destination $rccpDir -Recurse -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot "schemas") -Destination $rccpDir -Recurse -Force

$shim = @'
$ErrorActionPreference = "Stop"
$entry = Join-Path $PSScriptRoot ".rccp/scripts/rccp/rccp.ps1"
& $entry @args
'@

Set-Content -LiteralPath (Join-Path $targetPath "rccp.ps1") -Value $shim -Encoding UTF8

Write-Host "RCCP installed into $targetPath"
Write-Host "Try: pwsh -NoProfile -File rccp.ps1 -Action help"
