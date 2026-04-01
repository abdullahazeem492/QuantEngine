#!/bin/bash
# High-Performance Manual Build for WSL2 (Linux)

# Paths (Adjust if your installation is different)
NVCC=/usr/local/cuda/bin/nvcc
MPICXX=/usr/bin/mpicxx

# Compiler flags
CXX_FLAGS="-std=c++17 -O3 -fopenmp -I./include"
NVCC_FLAGS="-gencode arch=compute_75,code=sm_75 -gencode arch=compute_80,code=sm_80 -gencode arch=compute_86,code=sm_86 -I./include"

echo "🔨 Compiling QuantEngine (Linux Build) in WSL2..."

# Step 1: Compile CUDA sources
$NVCC $NVCC_FLAGS -c src/simulator.cu -o build_linux_simulator.o
if [ $? -ne 0 ]; then echo "❌ CUDA Compilation failed"; exit 1; fi

# Step 2: Compile C++ sources
g++ $CXX_FLAGS -c src/parser.cpp -o build_linux_parser.o
g++ $CXX_FLAGS -D_OPENMP -I/usr/lib/x86_64-linux-gnu/openmpi/include -c src/main.cpp -o build_linux_main.o
if [ $? -ne 0 ]; then echo "❌ C++ Compilation failed"; exit 1; fi

# Step 3: Link everything using MPI
$MPICXX $CXX_FLAGS build_linux_main.o build_linux_parser.o build_linux_simulator.o -L/usr/local/cuda/lib64 -lcudart -o quantpdc_linux
if [ $? -ne 0 ]; then echo "❌ Linking failed"; exit 1; fi

# Finalize
rm build_linux_*.o
echo "✅ Build Successful: Created 'quantpdc_linux'"
chmod +x quantpdc_linux
