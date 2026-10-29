@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
set "PATH=%~dp0Qt\6.8.3\msvc2022_64\bin;%PATH%"
set "TEMP=%~dp0temp"
set "TMP=%~dp0temp"
"%~dp0Qt\6.8.3\msvc2022_64\bin\windeployqt.exe" --release --qmldir "%~dp0..\outputs\Earth-and-Sky\source" --no-translations "%~dp0..\outputs\Earth-and-Sky\app\Earth-and-Sky.exe"
exit /b %errorlevel%
