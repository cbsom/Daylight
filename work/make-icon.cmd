@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
set "QTROOT=%~dp0Qt\6.8.3\msvc2022_64"
set "PATH=%QTROOT%\bin;%PATH%"
set "TEMP=%~dp0temp"
set "TMP=%~dp0temp"
cl /nologo /EHsc /MD /std:c++17 /Zc:__cplusplus /permissive- /O2 /I"%QTROOT%\include" /I"%QTROOT%\include\QtCore" /I"%QTROOT%\include\QtGui" "%~dp0..\outputs\Earth-and-Sky\source\tools\make-icon.cpp" /Fo"%~dp0make-icon.obj" /Fe"%~dp0make-icon.exe" /link /LIBPATH:"%QTROOT%\lib" Qt6Core.lib Qt6Gui.lib
if errorlevel 1 exit /b 1
"%~dp0make-icon.exe" "%~dp0..\outputs\Earth-and-Sky\source\assets\world.jpg" "%~dp0..\outputs\Earth-and-Sky\source\assets\earth-and-sky"
exit /b %errorlevel%

