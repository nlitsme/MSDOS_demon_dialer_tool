@echo off
if "%1"=="" goto needparam
if exist %1 goto start
if exist %1.asm goto start
goto needfile
:start
tasm /m2 /w2 %1
if errorlevel 1 goto editfile
tlink /t %1
if errorlevel 1 goto editfile
goto end
:editfile
q %1.asm
goto start
:needfile
echo Invalid Filename %1
:needparam
echo Usage: mk filename
:end
