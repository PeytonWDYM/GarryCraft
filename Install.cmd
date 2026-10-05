@echo off
setlocal
rem Windows PowerShell must use its own modules, even when CMD starts from PowerShell 7.
set "PSModulePath="
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\Install.ps1" %*
set "result=%errorlevel%"
pause
exit /b %result%
