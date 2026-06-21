$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvActivate = Join-Path $ProjectRoot "tfenv\Scripts\Activate.ps1"

if (-not (Test-Path $VenvActivate)) {
    throw "Không tìm thấy env Python 3.11 tại: $VenvActivate"
}

Set-Location $ProjectRoot

$Existing = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 8000 -ErrorAction SilentlyContinue
if ($Existing) {
    $Existing |
        Select-Object -ExpandProperty OwningProcess -Unique |
        ForEach-Object {
            if ($_ -and $_ -ne $PID) {
                Stop-Process -Id $_ -Force
            }
        }
}

. $VenvActivate
$env:CHATBOT_ENABLE_MCP = "1"
$env:PYTHONIOENCODING = "utf-8"

Write-Host "Python:" (python --version)
Write-Host "MCP enabled:" $env:CHATBOT_ENABLE_MCP
Write-Host "Starting chatbot server at http://127.0.0.1:8000/chatbot.html"

python run.py
