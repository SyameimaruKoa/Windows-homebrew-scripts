@echo off
chcp 65001
taskkill /f /IM explorer.exe
start explorer.exe
@timeout /nobreak 2
@exit
