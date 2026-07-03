@echo off
setlocal DisableDelayedExpansion

set "CMD_SELF=%~f0"
set "CMD_REAL="

for /f "usebackq delims=" %%I in (`powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:CMD_SELF; try { $i=Get-Item -LiteralPath $p -Force; $t=$i.Target; if ($t) { if ($t -is [array]) { $t=$t[0] }; if (-not [System.IO.Path]::IsPathRooted($t)) { $t=[System.IO.Path]::GetFullPath((Join-Path $i.DirectoryName $t)) }; Write-Output $t } else { Write-Output $i.FullName } } catch { Write-Output $p }" 2^>nul`) do set "CMD_REAL=%%I"

if not defined CMD_REAL set "CMD_REAL=%~f0"

for %%I in ("%CMD_REAL%") do set "SCRIPT_DIR=%%~dpI"

set "SCRIPT=%SCRIPT_DIR%remove-edge.ps1"

if not exist "%SCRIPT%" (
    echo ERROR: PowerShell script not found.
    echo Looked in: %SCRIPT_DIR%
    echo Expected: remove-edge.ps1
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
exit /b %ERRORLEVEL%
