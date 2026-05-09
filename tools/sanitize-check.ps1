[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$AdditionalPatternPath = "",
    [switch]$Strict
)

$ErrorActionPreference = "Stop"

$rootPath = (Resolve-Path -LiteralPath $Root).Path
$literalPatterns = @(
    "C:\\Users\\",
    "账号",
    "密码",
    "密钥"
)

if (-not [string]::IsNullOrWhiteSpace($AdditionalPatternPath) -and (Test-Path -LiteralPath $AdditionalPatternPath)) {
    $literalPatterns += @(Get-Content -LiteralPath $AdditionalPatternPath | ForEach-Object { [string]$_ } | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and -not ([string]$_).TrimStart().StartsWith("#")
    })
}

$regexPatterns = @(
    "(?i)\b(secret|token|password)\s*[:=]\s*['""][^'""]+['""]",
    "(?i)\b(api[_-]?key|access[_-]?key)\s*[:=]\s*['""][^'""]+['""]"
)

$allowedRelative = @(
    "tools/sanitize-check.ps1"
)

$hits = New-Object System.Collections.Generic.List[object]
Get-ChildItem -LiteralPath $rootPath -Recurse -File -Force |
    Where-Object {
        $_.FullName -notmatch "\\.git\\" -and
        $_.FullName -notmatch "\\evidence\\latest\\"
    } |
    ForEach-Object {
        $relative = $_.FullName.Substring($rootPath.Length).TrimStart([char[]]@("\", "/")).Replace("\", "/")
        if ($allowedRelative -contains $relative) { return }
        $text = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
        foreach ($pattern in $literalPatterns) {
            if ($text -match [regex]::Escape($pattern)) {
                $hits.Add([ordered]@{
                    path = $relative
                    pattern = $pattern
                }) | Out-Null
            }
        }
        foreach ($pattern in $regexPatterns) {
            if ($text -match $pattern) {
                $hits.Add([ordered]@{
                    path = $relative
                    pattern = $pattern
                }) | Out-Null
            }
        }
    }

$result = [ordered]@{
    machineTag = "RCCP_SANITIZE_CHECK_V1"
    generatedAt = (Get-Date).ToString("s")
    root = $rootPath
    ok = ($hits.Count -eq 0)
    hitCount = $hits.Count
    hits = @($hits.ToArray())
}

$outDir = Join-Path $rootPath "evidence/latest"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outPath = Join-Path $outDir "sanitize-check-latest.json"
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outPath -Encoding UTF8

if ($Strict -and $hits.Count -gt 0) {
    Write-Error "sanitize-check failed: $($hits.Count) hit(s). Evidence: $outPath"
}

Write-Host "sanitize-check: ok=$($result.ok), hits=$($hits.Count), evidence=$outPath"
