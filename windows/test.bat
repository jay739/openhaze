@echo off
rem Builds and runs the update checker tests with the C# compiler built into
rem Windows, the same one build.bat uses. Exits 1 if any check fails.
setlocal
cd /d "%~dp0"

set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" (
    echo Could not find the .NET Framework C# compiler on this machine.
    echo Enable ".NET Framework 4.8" in "Turn Windows features on or off".
    exit /b 1
)

"%CSC%" /nologo /target:exe /out:tests\UpdateCheckerTests.exe ^
    /r:System.dll /r:System.Runtime.Serialization.dll ^
    UpdateChecker.cs tests\UpdateCheckerTests.cs
if errorlevel 1 exit /b 1

tests\UpdateCheckerTests.exe
exit /b %errorlevel%
