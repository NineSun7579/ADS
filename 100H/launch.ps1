param(
    [string]$Pds = '',
    [ValidateSet('compile','map','full')][string]$Stage = 'full'
)
$ErrorActionPreference = 'Stop'
$python = (Get-Command python -ErrorAction Stop).Source
$buildRoot = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fffffff'
$workDir = Join-Path $buildRoot $stamp
$stdout = Join-Path $buildRoot ($stamp + '.stdout.log')
$stderr = Join-Path $buildRoot ($stamp + '.stderr.log')
$script = Join-Path $PSScriptRoot 'build.py'
$arguments = @(('"{0}"' -f $script), '--stage', $Stage, '--work', ('"{0}"' -f $workDir))
if ($Pds) { $arguments += @('--pds', ('"{0}"' -f $Pds)) }
$process = Start-Process -FilePath $python -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
$record = [ordered]@{ pid=$process.Id; work=$workDir; stage=$Stage; stdout=$stdout; stderr=$stderr; launched=(Get-Date).ToString('o') }
$record | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $buildRoot ($stamp + '.launch.json'))
$record | ConvertTo-Json
Write-Host ('Wait after result.json appears: .\wait.ps1 -WorkDir "' + $workDir + '"')
