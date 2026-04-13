@echo off
setlocal enabledelayedexpansion

set REPO=KrishnaSSH/autobumper
set DIR=bin
set FILE=%DIR%\autobumper.exe
set TMP=%DIR%\autobumper.tmp.exe
set SUM=%DIR%\checksums.txt

if not exist %DIR% (
  mkdir %DIR%
)

echo fetching latest release...

for /f "delims=" %%i in ('powershell -Command ^
 "(Invoke-RestMethod https://api.github.com/repos/%REPO%/releases/latest).assets ^
 | Where-Object { $_.name -like 'autobumper-windows-amd64*.exe' } ^
 | Select-Object -ExpandProperty browser_download_url"') do set URL=%%i

if "%URL%"=="" (
  echo failed to find windows binary
  exit /b 1
)

echo downloading checksums...
powershell -Command "Invoke-WebRequest -Uri https://github.com/%REPO%/releases/latest/download/checksums.txt -OutFile %SUM%"

echo downloading binary...
powershell -Command "Invoke-WebRequest -Uri %URL% -OutFile %TMP%"

for /f "tokens=1,2" %%a in (%SUM%) do (
  if "%%b"=="autobumper-windows-amd64-v0.0.1.exe" set EXPECTED=%%a
)

if "%EXPECTED%"=="" (
  echo failed to extract checksum
  del %TMP%
  exit /b 1
)

for /f %%h in ('powershell -Command "Get-FileHash %TMP% -Algorithm SHA256 | Select-Object -ExpandProperty Hash"') do set ACTUAL=%%h

echo expected: %EXPECTED%
echo actual: %ACTUAL%

if /i not "%EXPECTED%"=="%ACTUAL%" (
  echo checksum verification failed
  del %TMP%
  exit /b 1
)

move /Y %TMP% %FILE%

echo running...
%FILE%

endlocal