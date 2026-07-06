@echo off
rem Builds OpenHaze.exe using the C# compiler that ships inside Windows itself.
rem No Visual Studio, no SDK, no downloads needed. Just double-click this file.
setlocal
cd /d "%~dp0"

set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" (
    echo Could not find the .NET Framework C# compiler on this machine.
    echo Enable ".NET Framework 4.8" in "Turn Windows features on or off".
    pause
    exit /b 1
)

echo Compiling OpenHaze...
"%CSC%" /nologo /target:winexe /platform:anycpu /optimize+ ^
    /win32manifest:app.manifest ^
    /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll ^
    /out:OpenHaze.exe ^
    NativeMethods.cs OpenHaze.cs SettingsForm.cs

if errorlevel 1 (
    echo.
    echo Build FAILED - see errors above.
    pause
    exit /b 1
)

echo.
echo Built OpenHaze.exe successfully.

if "%~1"=="--no-launch" exit /b 0
choice /c YN /m "Launch OpenHaze now"
if errorlevel 2 exit /b 0
start "" "%~dp0OpenHaze.exe"
