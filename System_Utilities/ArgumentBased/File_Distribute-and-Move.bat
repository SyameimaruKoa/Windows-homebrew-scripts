@echo off
%~d1
cd "%~dp1"
:roop
If not exist 1st  mkdir 1st
If not exist 2nd  mkdir 2nd
If not exist 3rd  mkdir 3rd
If not exist 4th  mkdir 4th
move %1 1st\
move %2 2nd\
move %3 3rd\
move %4 4th\
shift
shift
shift
shift
if not "%~1"=="" goto roop
exit /b