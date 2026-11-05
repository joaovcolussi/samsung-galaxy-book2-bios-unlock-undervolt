@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
cd /d "%~dp0"
cl /nologo /c /O1 /Oi /GS- /Gs999999 /Zl /W4 /wd4100 biosmod.c || exit /b 1
link /nologo /SUBSYSTEM:EFI_APPLICATION /ENTRY:efi_main /NODEFAULTLIB /FIXED:NO /MERGE:.rdata=.text /OUT:..\biosmod.efi biosmod.obj || exit /b 1
echo BUILD OK
