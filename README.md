# 📈 QuantEngine (quantpdc)

**QuantEngine** is a high-performance, distributed market data simulation engine designed for quantitative analysis and backtesting. Built with a focus on speed and scalability, it leverages **CUDA** for massive parallelization on GPUs and **MPI** for distributed cluster computing.

![QuantEngine Banner](https://img.shields.io/badge/Performance-HPC-blueviolet?style=for-the-badge&logo=nvidia)
![C++](https://img.shields.io/badge/C++-17-blue.svg?style=for-the-badge&logo=c%2B%2B)
![CUDA](https://img.shields.io/badge/CUDA-Enabled-green.svg?style=for-the-badge&logo=nvidia)
![MPI](https://img.shields.io/badge/MPI-Distributed-orange.svg?style=for-the-badge)

## 🚀 Key Features

- **Massive Parallelization**: Offloads heavy Moving Average (MA) calculations to NVIDIA GPUs using custom CUDA kernels.
- **Distributed Scalability**: Uses MPI to shard massive datasets across multiple compute nodes, enabling multi-terabyte dataset analysis.
- **Hybrid HPC Architecture**: Combines **MPI** (Distributed), **CUDA** (GPU acceleration), and **OpenMP** (CPU multi-threading) for maximum hardware utilization.
- **Real-time Performance Metrics**: Real-time throughput tracking (bars/sec) and distributed logging.
- **Automated Sharding**: Intelligent data distribution across clusters with automatic edge-case handling for sharded time-series data.

## 🛠 Tech Stack

- **Language**: C++17
- **GPU Acceleration**: NVIDIA CUDA
- **Distributed Computing**: OpenMPI / MS-MPI
- **Multi-threading**: OpenMP
- **Build System**: CMake 3.18+

## 📂 Project Structure

```text
QuantEngine/
├── include/            # Header files (Interfaces)
├── src/                # Implementation files (.cpp, .cu)
├── data/               # Market datasets (CSV)
├── build/              # Build artifacts
├── CMakeLists.txt      # Build configuration
├── build.bat           # Automated build script (Windows)
└── run_mpi.bat         # Distributed execution script
```

## ⚙️ Installation & Build

### Prerequisites
- **CUDA Toolkit** (11.0+)
- **MPI Implementation** (e.g., MS-MPI for Windows)
- **CMake** (3.18+)
- **C++ Compiler** (MSVC / GCC)

### Building the Engine
You can use the provided `build.bat` for a quick setup on Windows:
```powershell
./build.bat
```
Or manually:
```bash
mkdir build && cd build
cmake ..
cmake --build . --config Release
```

## 📊 Running the Simulation

The engine processes market data (e.g., `bitcoin_data.csv`) and runs a **Golden Cross Strategy** (50-day vs 200-day Moving Averages).

To run on a distributed cluster with 4 nodes:
```powershell
mpiexec -n 4 build/Release/quantpdc.exe
```
Or use the convenience script:
```powershell
./run_mpi.bat
```

## 📈 Dashboard Output

QuantEngine provides a formatted dashboard for each node, displaying trade signals, entry prices, and win-rate statistics:

```text
 [NODE-0 DASHBOARD]
 -----------------------------------------------------------------------------------------------
 TIMESTAMP           SIGNAL    ENTRY          FWD-50         VALIDATE                OUTCOME
 -----------------------------------------------------------------------------------------------
 2023-01-15 08:00    BUY       $21,450.50     $23,100.00     CORRECT                 PROFIT
 2023-02-10 12:00    SELL      $24,000.20     $22,500.00     CORRECT                 PROFIT
 -----------------------------------------------------------------------------------------------
 [MPI-0] success: 12 signals | win rate: 75.0%
```

## 🛡 License
Distributed under the MIT License. See `LICENSE` for more information.

---
**Author**: fa23-bse-091@cuilahore.edu.pk | [GitHub](https://github.com/abdullahazeem492)
