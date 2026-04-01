# 📈 QuantEngine (quantpdc)

**QuantEngine** is a high-performance, distributed market data simulation engine designed for quantitative analysis and backtesting. Built with a focus on speed and scalability, it leverages **CUDA** for massive parallelization on GPUs and **MPI** for distributed cluster computing.

![QuantEngine Banner](https://img.shields.io/badge/Performance-HPC-blueviolet?style=for-the-badge&logo=nvidia)
![C++](https://img.shields.io/badge/C++-17-blue.svg?style=for-the-badge&logo=c%2B%2B)
![CUDA](https://img.shields.io/badge/CUDA-Enabled-green.svg?style=for-the-badge&logo=nvidia)
![MPI](https://img.shields.io/badge/MPI-Distributed-orange.svg?style=for-the-badge)

## 🚀 NEW: Multi-Strategy Hub & Modern GUI

The latest version introduces a decoupled strategy architecture and a web-based control center.

### 🧠 Supported Strategies
- **Golden Cross**: Classic MA crossover with configurable Fast/Slow windows.
- **RSI Mean Reversion**: Trading oversold/overbought conditions on the GPU.
- **Bollinger Bands**: Volatility-based breakouts and mean reversion.

### 🖥️ Modern Web GUI
A beautiful, glassmorphism-inspired dark mode interface to control your MPI clusters without touching the terminal.
- **Control Cluster**: Configure strategy parameters from the sidebar.
- **Live Analytics**: Watch signal generation and win-rate statistics in real-time.
- **HPC Metrics**: Monitor throughput (bars/sec) directly from the dashboard.

## 🛠 Tech Stack
- **Engine**: C++17, NVIDIA CUDA, MPI, OpenMP
- **Backend Hub**: Node.js, Express (Wrapper API)
- **Frontend Hub**: HTML5, Vanilla CSS (Glassmorphism), JavaScript

## ⚙️ Installation & Build

### Engine Setup
Build the C++ core:
```bash
./build.bat
```

### GUI Setup
1. **Initialize Backend**:
   ```bash
   cd gui_backend
   npm install
   node server.js
   ```
2. **Launch Frontend**: 
   Simply open `gui/index.html` in your browser.

## 📊 Usage (CLI)

You can still run the engine via CLI with specialized flags:
```bash
mpiexec -n 4 build/Release/quantpdc.exe --strategy rsi --rsi-window 14 --rsi-oversold 30
```

---
**Author**: fa23-bse-091@cuilahore.edu.pk | [GitHub](https://github.com/abdullahazeem492)
