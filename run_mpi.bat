@echo off
echo =========================================
echo quantpdc mpi runner
echo =========================================
echo running quantpdc with 4 nodes...
echo =========================================

mpiexec -n 4 build\Release\quantpdc.exe

if %errorlevel% neq 0 (
    echo.
    echo [ERR] Execution failed. Ensure MS-MPI is installed.
)

pause
