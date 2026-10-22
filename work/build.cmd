@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
set "PATH=C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"
set "TEMP=%~dp0temp"
set "TMP=%~dp0temp"
cmake -S "%~dp0..\outputs\Daylight\source" -B "%~dp0build-nmake" -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="%~dp0Qt\6.8.3\msvc2022_64"
if errorlevel 1 exit /b 1
cmake --build "%~dp0build-nmake"
exit /b %errorlevel%
