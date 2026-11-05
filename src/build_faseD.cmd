@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
cd /d "%~dp0"
for %%F in (faseD_sonda faseD_menu) do (
  cl /nologo /c /O1 /Oi /GS- /Gs999999 /Zl /W4 /wd4100 %%F.c || exit /b 1
  link /nologo /SUBSYSTEM:EFI_APPLICATION /ENTRY:efi_main /NODEFAULTLIB /FIXED:NO /MERGE:.rdata=.text /OUT:..\%%F.efi %%F.obj || exit /b 1
)
echo BUILD OK
