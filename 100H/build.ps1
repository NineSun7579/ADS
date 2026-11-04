param(
    [string]$Pds = '',
    [ValidateSet('compile','map','full')][string]$Stage = 'full',
    [string]$WorkDir = '',
    [switch]$VerifyOnly
)
$ErrorActionPreference = 'Stop'
$arguments = @((Join-Path $PSScriptRoot 'build.py'), '--stage', $Stage)
if ($Pds) { $arguments += @('--pds', $Pds) }
if ($WorkDir) { $arguments += @('--work', $WorkDir) }
if ($VerifyOnly) { $arguments += '--verify-only' }
& python @arguments
exit $LASTEXITCODE
