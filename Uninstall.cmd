@echo off
setlocal
set "PSModulePath="
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\Uninstall.ps1" -PackageRoot "%~dp0." %*
set "result=%errorlevel%"
pause
exit /b %result%
