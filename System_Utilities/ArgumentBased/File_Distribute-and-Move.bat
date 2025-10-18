@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
setlocal enabledelayedexpansion
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help

rem 初期値
set "split_mode=folder_count"
set "folder_count=4"
set "files_per_folder=0"
set "argidx=1"

rem オプション解析
if /i "%~1"=="-n" (
    set "split_mode=files_per_folder"
    set /a files_per_folder=%~2
    set /a argidx=3
) else if "%~1" geq "2" if "%~1" leq "99" (
    set "folder_count=%~1"
    set /a argidx=2
)

rem ファイルリストを配列に格納
set "filelist="
set /a filecount=0
:collect_files
call set "file=%%%argidx%%%"
if "!file!"=="" goto :start_distribute
set /a filecount+=1
set "filelist=!filelist!|!file!"
set /a argidx+=1
goto :collect_files

:start_distribute
rem フォルダ生成
if "%split_mode%"=="folder_count" (
    for /l %%i in (1,1,%folder_count%) do (
        set "suffix=th"
        if %%i==1 set "suffix=st"
        if %%i==2 set "suffix=nd"
        if %%i==3 set "suffix=rd"
        if not exist %%i!suffix! mkdir %%i!suffix!
    )
) else (
    set /a folder_count=(filecount+files_per_folder-1)/files_per_folder
    for /l %%i in (1,1,!folder_count!) do (
        set "suffix=th"
        if %%i==1 set "suffix=st"
        if %%i==2 set "suffix=nd"
        if %%i==3 set "suffix=rd"
        if not exist %%i!suffix! mkdir %%i!suffix!
    )
)

rem ファイル振り分け
set /a idx=0
for %%F in (!filelist:|= !) do (
    set /a foldernum=0
    if "%split_mode%"=="folder_count" (
        set /a foldernum=idx %% folder_count + 1
    ) else (
        set /a foldernum=idx / files_per_folder + 1
    )
    set "suffix=th"
    if !foldernum!==1 set "suffix=st"
    if !foldernum!==2 set "suffix=nd"
    if !foldernum!==3 set "suffix=rd"
    move "%%F" !foldernum!!suffix!\
    set /a idx+=1
)
exit /b

:show_help
echo.
echo [概要]
echo   ファイルを指定分割数でフォルダに振り分けて移動します。
echo   または「-n 個数」で1フォルダあたりの個数指定も可能です。
echo.
echo [使い方]
echo   %~nx0 [分割数] <file1> <file2> ...
echo   %~nx0 -n <個数> <file1> <file2> ...
echo.
echo [例]
echo   %~nx0 4 file1.txt file2.txt file3.txt file4.txt file5.txt
echo   → 4分割で 1st/2nd/3rd/4th フォルダに順番に移動
echo   %~nx0 -n 5 file1.txt file2.txt ... file20.txt
echo   → 1フォルダ5個ずつで 1st/2nd/3rd/4th フォルダに移動
echo.
echo [注意]
echo   既存の同名ファイルがあると移動に失敗することがあります。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b