@echo off
echo =========================================
echo quantpdc build script (clean build)
echo =========================================

echo Checking for CMake...
where cmake >nul 2>&1
if errorlevel 1 goto nocmake

echo Checking for MSVC Compiler...
where cl >nul 2>&1
if errorlevel 1 goto nocl

if exist build (
    echo [SYS] removing old build cache...
    rd /s /q build
)
mkdir build

echo.
echo Initializing Build...
cd build
cmake .. -A x64
if errorlevel 1 goto cmakereview

echo.
echo Compiling...
cmake --build . --config Release
if errorlevel 1 goto buildfailed

echo.
echo [SUCCESS] Build Finished!
echo Executable: build\Release\quantpdc.exe
cd ..
pause
exit /b 0

:nocmake
echo [ERR] CMake not found. Please install CMake 3.18+.
pause
exit /b 1

:nocl
echo [ERR] MSVC (cl.exe) not in PATH. 
echo Please run this from 'x64 Native Tools Command Prompt'.
pause
exit /b 1

:cmakereview
echo [ERR] CMake configuration failed. 
cd ..
pause
exit /b 1

:buildfailed
echo [ERR] Compilation failed!
cd ..
pause
exit /b 1
