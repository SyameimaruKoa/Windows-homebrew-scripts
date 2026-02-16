@chcp 932
@cd /D C:\RAMDASK\
@if %errorlevel%==1 (
echo "RAMディスクが見つかりませんでした。Downloadフォルダに移動します"
cd /D "%USERPROFILE%\Downloads"
)
aria2c https://github.com/SideStore/SideStore/releases/download/nightly/SideStore.ipa
@exit