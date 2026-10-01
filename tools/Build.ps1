param(
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$CMake = "cmake"
)
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
if (-not $JavaHome) {
    $javaInstall = Get-ChildItem "$env:LOCALAPPDATA\GarryCraft\tools\java" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if (-not $javaInstall) { throw 'Install JDK 25 or set JAVA_HOME.' }
    $JavaHome = $javaInstall.FullName
}
$env:JAVA_HOME = $JavaHome
if (-not (Get-Command $CMake -ErrorAction SilentlyContinue)) {
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vsPath = & $vsWhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    $CMake = Join-Path $vsPath 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
}
& $CMake -S "$repository\native" -B "$repository\native\build" -A x64
if ($LASTEXITCODE) { throw 'Native configuration failed.' }
& $CMake --build "$repository\native\build" --config Release
if ($LASTEXITCODE) { throw 'Native build failed.' }
& "$repository\fabric\gradlew.bat" -p "$repository\fabric" build
if ($LASTEXITCODE) { throw 'Fabric build failed.' }
