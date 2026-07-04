@echo off
REM ============================================================================
REM pwsh-profile.cmd - opencode shell override that LOADS $PROFILE
REM
REM Why: opencode and others launch its configured shell with -NoProfile -NonInteractive
REM -Command "<script>" for every bash-tool invocation. -NoProfile skips your
REM $PROFILE and the modular Scripts\*.ps1, so auth-health, opr, etc. are
REM missing in opencode-driven shells.
REM
REM What: This wrapper strips -NoProfile from opencode's args and forwards
REM everything else. The launched pwsh therefore runs $PROFILE first, then
REM honors -NonInteractive -Command "..." as usual.
REM
REM Trade-off: profile load adds ~200-500ms to every bash-tool call. Acceptable
REM for interactive opencode sessions. If you script with opencode programmatically
REM and care about latency, point opencode back at "pwsh" instead.
REM ============================================================================

setlocal EnableDelayedExpansion
set "ARGS="
:loop
if "%~1"=="" goto run
if /I "%~1"=="-NoProfile" goto skip
if /I "%~1"=="--NoProfile" goto skip
set "ARGS=!ARGS! %1"
shift
goto loop
:skip
shift
goto loop
:run
"C:\Program Files\PowerShell\7\pwsh.exe" %ARGS%
endlocal
