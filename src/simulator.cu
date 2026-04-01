#include <iostream>
#include <vector>
#include <iomanip>
#include <sstream>
#include <cuda_runtime.h>

#include "parser.hpp"
#include "simulator.hpp"

// golden cross kernel
__global__ void golden_cross_kernel(float* prices, float* fast_ma, float* slow_ma, int n, int fast_w, int slow_w) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        if (i < fast_w - 1) {
            fast_ma[i] = 0;
        } else {
            float sum = 0;
            for (int k = 0; k < fast_w; ++k) sum += prices[i - k];
            fast_ma[i] = sum / fast_w;
        }

        if (i < slow_w - 1) {
            slow_ma[i] = 0;
        } else {
            float sum = 0;
            for (int k = 0; k < slow_w; ++k) sum += prices[i - k];
            slow_ma[i] = sum / slow_w;
        }
    }
}

void run_strategy_simulation(const MarketData& data, int rank, int start_pos, int end_pos) {
    if (data.size == 0) return;

    int n = (int)data.size;
    float *d_prices, *d_fast, *d_slow;
    size_t mem_size = n * sizeof(float);
    
    // gpu memory
    cudaMalloc(&d_prices, mem_size);
    cudaMalloc(&d_fast, mem_size);
    cudaMalloc(&d_slow, mem_size);

    cudaMemcpy(d_prices, data.close.data(), mem_size, cudaMemcpyHostToDevice);

    int fast_window = 50, slow_window = 200; 
    int threadsPerBlock = 256;
    int blocksPerGrid = (n + threadsPerBlock - 1) / threadsPerBlock;
    
    // run kernel
    golden_cross_kernel<<<blocksPerGrid, threadsPerBlock>>>(d_prices, d_fast, d_slow, n, fast_window, slow_window);
    cudaDeviceSynchronize();

    std::vector<float> h_fast(n), h_slow(n);
    cudaMemcpy(h_fast.data(), d_fast, mem_size, cudaMemcpyDeviceToHost);
    cudaMemcpy(h_slow.data(), d_slow, mem_size, cudaMemcpyDeviceToHost);

    // trading dashboard
    std::stringstream log;
    log << "\n \033[1;33m[NODE-" << rank << " DASHBOARD]\033[0m" << std::endl;
    log << " " << std::string(95, '-') << std::endl;
    log << " " << std::left << std::setw(20) << "TIMESTAMP" << std::setw(12) << "SIGNAL" 
        << std::setw(15) << "ENTRY" << std::setw(15) << "FWD-50" << std::setw(15) << "VALIDATE" << "OUTCOME" << std::endl;
    log << " " << std::string(95, '-') << std::endl;

    int signals = 0, correct = 0, look_forward = 50; 
    int effective_start = (start_pos < slow_window) ? slow_window : start_pos;

    for (int i = effective_start; i < end_pos; ++i) {
        bool buy = (h_fast[i-1] <= h_slow[i-1] && h_fast[i] > h_slow[i]);
        bool sell = (h_fast[i-1] >= h_slow[i-1] && h_fast[i] < h_slow[i]);

        if (buy || sell) {
            float entry = data.close[i];
            float forward = (i + look_forward < n) ? data.close[i + look_forward] : -1.0f;
            std::string sig = buy ? "\033[1;32mBUY \033[0m" : "\033[1;31mSELL\033[0m";
            std::string val = "N/A", res = "---";

            if (forward > 0) {
                bool win = (buy && forward > entry) || (sell && forward < entry);
                val = win ? "\033[1;32mCORRECT\033[0m" : "\033[1;31mINCORRECT\033[0m";
                res = win ? "PROFIT" : "LOSS";
                if (win) correct++;
            }
            log << " " << std::left << std::setw(20) << data.dates[i] << std::setw(20) << sig 
                << "$" << std::setw(14) << std::fixed << std::setprecision(2) << entry
                << "$" << std::setw(14) << forward << std::setw(24) << val << res << std::endl;
            signals++;
        }
    }
    
    if (signals > 0) {
        std::cout << log.str() << " " << std::string(95, '-') << std::endl;
        std::cout << " [MPI-" << rank << "] success: " << signals << " signals | win rate: " << (float)correct/signals*100 << "%" << std::endl;
    }

    cudaFree(d_prices); cudaFree(d_fast); cudaFree(d_slow);
}
