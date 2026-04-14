@echo off
setlocal enabledelayedexpansion

set REPO=KrishnaSSH/autobumper
set DIR=bin
set FILE=%DIR%\autobumper.exe
set TMP=%DIR%\autobumper.tmp.exe
set SUM=%DIR%\checksums.txt
set VERFILE=%DIR%\version.txt

if not exist %DIR% mkdir %DIR%

echo fetching latest release...

for /f "delims=" %%i in ('
powershell -Command "(Invoke-RestMethod https://api.github.com/repos/%REPO%/releases/latest).tag_name"
') do set LATEST=%%i

set CURRENT=
if exist %VERFILE% set /p CURRENT=<%VERFILE%

echo current: %CURRENT%
echo latest: %LATEST%

if "%CURRENT%"=="%LATEST%" if exist %FILE% (
  echo already up to date
  %FILE%
  exit /b 0
)

for /f "delims=" %%i in ('
powershell -Command ^
 "(Invoke-RestMethod https://api.github.com/repos/%REPO%/releases/latest).assets ^
 | Where-Object { $_.name -like 'autobumper-windows-%PROCESSOR_ARCHITECTURE%-*' } ^
 | Select-Object -ExpandProperty browser_download_url"
') do set URL=%%i

if "%URL%"=="" (
  echo failed to find binary
  exit /b 1
)

echo downloading files...

powershell -Command "Invoke-WebRequest https://github.com/%REPO%/releases/latest/download/checksums.txt -OutFile %SUM%"
powershell -Command "Invoke-WebRequest %URL% -OutFile %TMP%"

for /f "tokens=1,2" %%a in (%SUM%) do (
  echo %%b | findstr /i "autobumper-windows" >nul
  if !errorlevel! == 0 set EXPECTED=%%a
)

for /f %%h in ('
powershell -Command "Get-FileHash %TMP% -Algorithm SHA256 | Select-Object -ExpandProperty Hash"
') do set ACTUAL=%%h

echo expected: %EXPECTED%
echo actual: %ACTUAL%

if /i not "%EXPECTED%"=="%ACTUAL%" (
  echo checksum failed
  del %TMP%
  exit /b 1
)

move /Y %TMP% %FILE%

echo %LATEST% > %VERFILE%

echo running...
%FILE%

endlocal