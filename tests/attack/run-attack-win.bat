@echo off
rem Runs the adversarial scenarios (tests\attack) on Windows with clang++ (GNU-style driver, MSVC STL).
rem   tests\attack\run-attack-win.bat          uses the first cmake.exe on PATH
rem   set CMAKE_EXE=C:\path\cmake.exe           choose another CMake (tested 4.5.0)
rem   set SCEN=a03;a05                           subset (prefix match on the variant id)
rem Needs clang++ and ninja on PATH, the MSVC environment (a VS Developer prompt, or vcvars64.bat located
rem via vswhere), and fmt / nlohmann_json sources in ext-src\ (see README).  Results: _build\attack-win\results.txt
setlocal
set "HERE=%~dp0"
if defined VCINSTALLDIR goto haveenv
set "PF86=%ProgramFiles(x86)%"
rem fallback in case ProgramFiles(x86) is not in the environment
if not defined PF86 set "PF86=%SystemDrive%\Program Files (x86)"
set "VSDIR="
pushd "%PF86%\Microsoft Visual Studio\Installer" 2>nul && (
  for /f "delims=" %%i in ('.\vswhere.exe -latest -products * -property installationPath') do set "VSDIR=%%i"
  popd
)
if not defined VSDIR (echo run-attack-win.bat: Visual Studio not found; open a VS Developer prompt & exit /b 1)
call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat" >nul
:haveenv
if not defined CMAKE_EXE for /f "delims=" %%i in ('where cmake.exe') do if not defined CMAKE_EXE set "CMAKE_EXE=%%i"
"%CMAKE_EXE%" -DTC=win "-DCMAKE_EXE=%CMAKE_EXE%" "-DSCEN=%SCEN%" -P "%HERE%run_attack.cmake"
echo.
type "%HERE%..\..\_build\attack-win\results.txt"
endlocal
