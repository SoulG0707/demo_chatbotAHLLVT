$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Python = Join-Path $ProjectRoot "tfenv\Scripts\python.exe"
$Requirements = Join-Path $ProjectRoot "requirements-mcp.txt"

if (-not (Test-Path $Python)) {
    throw "Không tìm thấy Python trong tfenv: $Python"
}

if (-not (Test-Path $Requirements)) {
    throw "Không tìm thấy file requirements MCP: $Requirements"
}

Set-Location $ProjectRoot

& $Python -m pip install --upgrade pip
& $Python -m pip install -r $Requirements

Write-Host "Đã cài dependency MCP. Kiểm tra nhanh:"
& $Python -c "import mcp; print('mcp import OK')"
