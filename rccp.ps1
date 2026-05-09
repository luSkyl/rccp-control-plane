$ErrorActionPreference = "Stop"

$entry = Join-Path $PSScriptRoot "scripts/rccp/rccp.ps1"
if (-not (Test-Path -LiteralPath $entry)) {
    throw "RCCP entry not found: $entry"
}

& $entry @args
