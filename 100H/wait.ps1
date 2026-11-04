param([Parameter(Mandatory=$true)][string]$WorkDir)
$ErrorActionPreference = 'Stop'
$resultFile = Join-Path $WorkDir 'result.json'
if (!(Test-Path $resultFile)) { throw 'result.json not found' }
$state = Get-Content $resultFile -Raw | ConvertFrom-Json
if ($state.status -eq 'RUNNING') {
    $process = Get-Process -Id $state.pid -ErrorAction SilentlyContinue
    if ($process) { Wait-Process -Id $state.pid }
}
$state = Get-Content $resultFile -Raw | ConvertFrom-Json
$state | ConvertTo-Json -Depth 10
if ($state.status -like 'PASS_*') { exit 0 }
if ($state.status -eq 'RUNNING') { throw 'Driver exited without final state; inspect logs; do not reuse outputs' }
exit 1
