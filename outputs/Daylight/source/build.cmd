@echo off
setlocal
rem Run from an x64 Visual Studio Developer Command Prompt.
rem Usage: build.cmd C:\Qt\6.8.3\msvc2022_64
if "%~1"=="" (
  echo Usage: build.cmd path-to-Qt-msvc2022_64
  exit /b 1
)
cmake -S "%~dp0" -B "%~dp0build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="%~1"
if errorlevel 1 exit /b 1
cmake --build "%~dp0build"
if errorlevel 1 exit /b 1
if not exist "%~dp0..\app" mkdir "%~dp0..\app"
copy /y "%~dp0build\Daylight.exe" "%~dp0..\app\Daylight.exe"
"%~1\bin\windeployqt.exe" --release --qmldir "%~dp0" --no-translations "%~dp0..\app\Daylight.exe"
exit /b %errorlevel%
