$ErrorActionPreference = 'Stop'
$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    & $python.Source "$PSScriptRoot\tools\build.py" @args
} else {
    & py -3 "$PSScriptRoot\tools\build.py" @args
}
exit $LASTEXITCODE
