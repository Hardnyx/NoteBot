@echo off
setlocal
rem Builds NoteBot: compiles the source, optionally runs the regression checks and
rem produces the installer in the dist folder. Any argument is passed straight to
rem build.ps1, for example: compile.bat -Portable

cd /d "%~dp0"

set "ARGS=%*"
set "TEST_FLAG="

echo Removing the mark of the web from the extracted files...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Recurse -File | Unblock-File"

rem Skip the question when the caller already decided on the command line.
echo.%ARGS% | findstr /i /c:"SkipTests" >nul
if errorlevel 1 (
    echo.
    echo The regression checks open and close note windows on screen for a few seconds.
    echo Skipping them does not change what is built.
    set /p "RUN_TESTS=Run the checks before building? [Y/n]: "
)

if /i "%RUN_TESTS%"=="n" set "TEST_FLAG=-SkipTests"
if /i "%RUN_TESTS%"=="no" set "TEST_FLAG=-SkipTests"

echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_SETUP\Windows\build.ps1" %TEST_FLAG% %ARGS%
set BUILD_RESULT=%ERRORLEVEL%

echo.
if %BUILD_RESULT% neq 0 (
    echo The build failed. Read the messages above for the reason.
) else (
    echo The build finished. The files are in the dist folder.
)

echo.
pause
exit /b %BUILD_RESULT%
