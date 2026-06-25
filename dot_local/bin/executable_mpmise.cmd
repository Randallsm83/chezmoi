@echo off
setlocal
set "SCRIPT=%~dp0mpmise.py"
python "%SCRIPT%" %*
exit /b %ERRORLEVEL%
