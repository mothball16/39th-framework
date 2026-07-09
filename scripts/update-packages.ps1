Set-Location (Resolve-Path (Join-Path $PSScriptRoot ".."))

function Exit-IfFailed {
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$conn = Get-NetTCPConnection -LocalPort 34872 -ErrorAction SilentlyContinue
if ($conn) {
    $conn | ForEach-Object {
        Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
    }
}

wally install
Exit-IfFailed

rojo sourcemap default.project.json --output sourcemap.json
Exit-IfFailed

wally-package-types --sourcemap sourcemap.json Packages/
Exit-IfFailed
