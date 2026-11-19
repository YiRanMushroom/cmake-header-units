@echo off
rem Runs the test suite on Windows with clang-cl (Clang's MSVC-style driver, MSVC STL).
rem   run-clangcl.bat                    uses the first cmake.exe on PATH
rem   set CMAKE_EXE=C:\path\cmake.exe    choose another CMake (>= 4.2)
rem   set TESTS=t01;t07                  run a subset
rem   set CLANG_CXX=C:\llvm\bin\clang-cl.exe  a clang-cl other than the first on PATH (vcvars64.bat puts Visual
rem                                      Studio's own, older Clang before it)
rem Needs clang-cl and ninja on PATH, the MSVC environment (a VS Developer prompt, or vcvars64.bat is
rem located via vswhere), and fmt 10.1.1 + nlohmann_json 3.11.3 sources in ext-src\ (see README).
setlocal
set "HERE=%~dp0"
if defined VCINSTALLDIR goto haveenv
set "PF86=%ProgramFiles(x86)%"
if not defined PF86 set "PF86=C:\Program Files (x86)"
set "VSDIR="
pushd "%PF86%\Microsoft Visual Studio\Installer" 2>nul && (
  for /f "delims=" %%i in ('.\vswhere.exe -latest -products * -property installationPath') do set "VSDIR=%%i"
  popd
)
if not defined VSDIR (echo run-clangcl.bat: Visual Studio not found; open a VS Developer prompt & exit /b 1)
call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat" >nul
:haveenv
if not defined CMAKE_EXE for /f "delims=" %%i in ('where cmake.exe') do if not defined CMAKE_EXE set "CMAKE_EXE=%%i"
"%CMAKE_EXE%" -DTC=clangcl "-DCMAKE_EXE=%CMAKE_EXE%" -DTAG=local "-DTESTS=%TESTS%" "-DCLANG_CXX=%CLANG_CXX%" -P "%HERE%tests\run_suite.cmake"
echo.
echo toolchain^|cmake^|test^|verdict^|time^|evidence
type "%HERE%_build\clangcl-local\results.txt"
endlocal
