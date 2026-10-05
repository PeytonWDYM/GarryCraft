@echo off
setlocal
set "PSModulePath="
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\Play.ps1" -PackageRoot "%~dp0."
set "result=%errorlevel%"
if errorlevel 1 pause
exit /b %result%
