@echo off
setlocal enabledelayedexpansion
set REPO=KrishnaSSH/autobumper
set DIR=bin
set FILE=%DIR%\autobumper.exe
set SUM=%DIR%\checksums.txt
set VERFILE=%DIR%\version.txt

if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" set ARCH=amd64
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set ARCH=arm64
if /i "%PROCESSOR_ARCHITECTURE%"=="x86"   set ARCH=386

if not exist %DIR% mkdir %DIR%

echo fetching latest release...
for /f "delims=" %%i in ('powershell -Command "(Invoke-RestMethod https://api.github.com/repos/%REPO%/releases/latest).tag_name"') do set LATEST=%%i

set CURRENT=
if exist %VERFILE% set /p CURRENT=<%VERFILE%
echo current: %CURRENT%
echo latest: %LATEST%

if "%CURRENT%"=="%LATEST%" if exist %FILE% (
  echo already up to date
  %FILE%
  exit /b 0
)

set ARCHIVE=autobumper-windows-%ARCH%-%LATEST%.tar.gz
set TMP_ARCHIVE=%DIR%\%ARCHIVE%
set URL=https://github.com/%REPO%/releases/download/%LATEST%/%ARCHIVE%

echo downloading files...
powershell -Command "Invoke-WebRequest https://github.com/%REPO%/releases/download/%LATEST%/checksums.txt -OutFile %SUM%"
powershell -Command "Invoke-WebRequest '%URL%' -OutFile '%TMP_ARCHIVE%'"

for /f "tokens=1,2" %%a in (%SUM%) do (
  echo %%b | findstr /i "%ARCHIVE%" >nul
  if !errorlevel! == 0 set EXPECTED=%%a
)

for /f %%h in ('powershell -Command "Get-FileHash '%TMP_ARCHIVE%' -Algorithm SHA256 | Select-Object -ExpandProperty Hash"') do set ACTUAL=%%h

echo expected: %EXPECTED%
echo actual: %ACTUAL%

if /i not "%EXPECTED%"=="%ACTUAL%" (
  echo checksum failed
  del "%TMP_ARCHIVE%"
  exit /b 1
)

powershell -Command "tar -xzf '%TMP_ARCHIVE%' -C '%DIR%'"
del "%TMP_ARCHIVE%"

for /f "delims=" %%f in ('powershell -Command "Get-ChildItem %DIR%\autobumper-windows-%ARCH%*.exe | Select-Object -ExpandProperty Name"') do (
  move /Y "%DIR%\%%f" "%FILE%" >nul
)

echo %LATEST% > %VERFILE%
echo running...
%FILE%
endlocal

