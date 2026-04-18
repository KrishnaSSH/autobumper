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

rem --- If versions match and binary exists, verify checksum before running ---
if "%CURRENT%"=="%LATEST%" if exist %FILE% (
  echo versions match, verifying checksum...
  call :verify_checksum
  if !CHECKSUM_OK!==1 (
    echo checksum ok, already up to date
    goto run
  )
  echo checksum missing or mismatch -- redownloading...
  goto download
)

:download
set ARCHIVE=autobumper-windows-%ARCH%-%LATEST%.tar.gz
set TMP_ARCHIVE=%DIR%\%ARCHIVE%
set URL=https://github.com/%REPO%/releases/download/%LATEST%/%ARCHIVE%

echo downloading checksums...
powershell -Command "Invoke-WebRequest 'https://github.com/%REPO%/releases/download/%LATEST%/checksums.txt' -OutFile '%SUM%'"

echo downloading %ARCHIVE%...
powershell -Command "Invoke-WebRequest '%URL%' -OutFile '%TMP_ARCHIVE%'"

call :checksum_archive
if !CHECKSUM_OK!==0 (
  echo checksum failed
  del "%TMP_ARCHIVE%"
  exit /b 1
)

powershell -Command "tar -xzf '%TMP_ARCHIVE%' -C '%DIR%'"
del "%TMP_ARCHIVE%"

for /f "delims=" %%f in ('powershell -Command "Get-ChildItem '%DIR%\autobumper-windows-%ARCH%*.exe' | Select-Object -ExpandProperty Name"') do (
  move /Y "%DIR%\%%f" "%FILE%" >nul
)

echo %LATEST%> %VERFILE%
echo installed %LATEST%

:run
echo running...
%FILE%
endlocal
exit /b 0


rem -----------------------------------------------------------------------
rem :verify_checksum
rem   Checks whether a local checksums.txt exists and contains a matching
rem   hash for the current binary.  Sets CHECKSUM_OK=1 on success, 0 on fail.
rem -----------------------------------------------------------------------
:verify_checksum
set CHECKSUM_OK=0

if not exist %SUM% (
  echo no local checksums.txt found
  exit /b 0
)

rem Look for a direct binary hash entry (filename: autobumper.exe)
set BIN_EXPECTED=
for /f "tokens=1,2" %%a in (%SUM%) do (
  if /i "%%b"=="autobumper.exe" set BIN_EXPECTED=%%a
)

if "!BIN_EXPECTED!"=="" (
  rem No binary entry in checksum file — treat as missing/stale
  echo no binary checksum entry found in checksums.txt
  exit /b 0
)

for /f %%h in ('powershell -Command "Get-FileHash '%FILE%' -Algorithm SHA256 | Select-Object -ExpandProperty Hash"') do set ACTUAL=%%h

echo expected: !BIN_EXPECTED!
echo actual:   !ACTUAL!

if /i "!BIN_EXPECTED!"=="!ACTUAL!" set CHECKSUM_OK=1
exit /b 0


rem -----------------------------------------------------------------------
rem :checksum_archive
rem   Verifies the downloaded archive against checksums.txt.
rem   Sets CHECKSUM_OK=1 on success, 0 on fail.
rem -----------------------------------------------------------------------
:checksum_archive
set CHECKSUM_OK=0
set EXPECTED=

for /f "tokens=1,2" %%a in (%SUM%) do (
  echo %%b | findstr /i "%ARCHIVE%" >nul
  if !errorlevel!==0 set EXPECTED=%%a
)

for /f %%h in ('powershell -Command "Get-FileHash '%TMP_ARCHIVE%' -Algorithm SHA256 | Select-Object -ExpandProperty Hash"') do set ACTUAL=%%h

echo expected: %EXPECTED%
echo actual:   %ACTUAL%

if /i "%EXPECTED%"=="%ACTUAL%" set CHECKSUM_OK=1
exit /b 0

