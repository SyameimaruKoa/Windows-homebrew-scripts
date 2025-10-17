@echo off
chcp 932
if "%~x1"=="" goto folder

:file
cd /D "%~dp1"
move %1 ../
if %errorlevel%==0 rmdir "%~dp1" > nul
shift
if not "%~1"=="" goto file
timeout /nobreak 1
exit

:folder
cd /D %1
for /r %%i in (*) do move "%%i" ../
cd ../
rmdir %1 > nul
shift
if not "%~1"=="" goto folder
timeout /nobreak 1
exit