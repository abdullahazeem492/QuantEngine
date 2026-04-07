#include <iostream>
#include <vector>
#include <iomanip>
#include <sstream>
#include <cuda_runtime.h>
#include <math.h>

#include "parser.hpp"
#include "simulator.hpp"
#include "config.hpp"

/* 
 * CUDA PARALLEL KERNELS
 * 
 * In standard CPU code, calculating moving averages requires a loop 
 * over the entire dataset O(N). In CUDA, we use SIMT (Single Instruction, 
 * Multiple Threads). We launch thousands of threads simultaneously. 
 * 'i' represents the global index mapped to a specific thread. 
 * Each thread calculates the moving average for ONE specific point in time.
 * */

// 1. Golden Cross Kernel (Moving Averages)
__global__ void golden_cross_kernel(float* prices, float* fast_ma, float* slow_ma, int n, int fast_w, int slow_w) {
    // Calculate global thread ID
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    
    // Ensure thread is within array bounds
    if (i < n) {
        // Fast Moving Average
        if (i < fast_w - 1) {
            fast_ma[i] = 0; // Not enough data
        } else {
            float sum = 0;
            // Thread computes the trailing sum for its specific index 'i'
            for (int k = 0; k < fast_w; ++k) sum += prices[i - k];
            fast_ma[i] = sum / fast_w;
        }

        // Slow Moving Average
        if (i < slow_w - 1) {
            slow_ma[i] = 0;
        } else {
            float sum = 0;
            for (int k = 0; k < slow_w; ++k) sum += prices[i - k];
            slow_ma[i] = sum / slow_w;
        }
    }
}

// 2. Relative Strength Index (RSI) Kernel
__global__ void rsi_kernel(float* prices, float* rsi, int n, int window) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        if (i < window) {
            rsi[i] = 50.0f; // Neutral default
        } else {
            float gain = 0.0f;
            float loss = 0.0f;
            for (int k = 0; k < window; ++k) {
                float diff = prices[i - k] - prices[i - k - 1];
                if (diff > 0) gain += diff;
                else loss -= diff;
            }
            gain /= window;
            loss /= window;
            
            if (loss == 0) {
                rsi[i] = 100.0f;
            } else {
                float rs = gain / loss;
                rsi[i] = 100.0f - (100.0f / (1.0f + rs));
            }
        }
    }
}

// 3. Bollinger Bands (Variance & StdDev) Kernel
__global__ void bollinger_kernel(float* prices, float* ma, float* upper, float* lower, int n, int window, float stddev_mult) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        if (i < window - 1) {
            ma[i] = 0; upper[i] = 0; lower[i] = 0;
        } else {
            float sum = 0;
            for (int k = 0; k < window; ++k) sum += prices[i - k];
            float mean = sum / window;
            ma[i] = mean;
            
            // Calculate variance using GPU hardware
            float var_sum = 0;
            for (int k = 0; k < window; ++k) {
                float diff = prices[i - k] - mean;
                var_sum += diff * diff;
            }
            float stddev = sqrt(var_sum / window);
            
            upper[i] = mean + (stddev_mult * stddev);
            lower[i] = mean - (stddev_mult * stddev);
        }
    }
}

/* 
 * HOST EXECUTION BLOCK
 * Orchestrates memory transfer between RAM (Host) and VRAM (Device)
 *  */

void run_strategy_simulation(const MarketData& data, const StrategyConfig& config, int rank, int start_pos, int end_pos) {
    if (data.size == 0) return;

    int n = (int)data.size;
    float *d_prices;
    size_t mem_size = n * sizeof(float);
    
    // Allocate VRAM and copy price array from Host to Device
    cudaMalloc(&d_prices, mem_size);
    cudaMemcpy(d_prices, data.close.data(), mem_size, cudaMemcpyHostToDevice);

    // Compute GPU Grid topology
    int threadsPerBlock = 256;
    int blocksPerGrid = (n + threadsPerBlock - 1) / threadsPerBlock;
    
    std::vector<bool> buy_signals(n, false);
    std::vector<bool> sell_signals(n, false);
    int effective_start = start_pos;

    // Launch appropriate kernel based on strategy
    if (config.type == StrategyType::GOLDEN_CROSS) {
        float *d_fast, *d_slow;
        cudaMalloc(&d_fast, mem_size);
        cudaMalloc(&d_slow, mem_size);
        
        // Asynchronous Kernel Launch
        golden_cross_kernel<<<blocksPerGrid, threadsPerBlock>>>(d_prices, d_fast, d_slow, n, config.fast_window, config.slow_window);
        cudaDeviceSynchronize(); // Wait for GPU to finish

        // Copy calculated indicators back to Host RAM
        std::vector<float> h_fast(n), h_slow(n);
        cudaMemcpy(h_fast.data(), d_fast, mem_size, cudaMemcpyDeviceToHost);
        cudaMemcpy(h_slow.data(), d_slow, mem_size, cudaMemcpyDeviceToHost);
        
        // Evaluate signals on CPU for the assigned MPI shard
        effective_start = (start_pos < config.slow_window) ? config.slow_window : start_pos;
        for (int i = effective_start; i < end_pos; ++i) {
            buy_signals[i] = (h_fast[i-1] <= h_slow[i-1] && h_fast[i] > h_slow[i]);
            sell_signals[i] = (h_fast[i-1] >= h_slow[i-1] && h_fast[i] < h_slow[i]);
        }
        
        cudaFree(d_fast); cudaFree(d_slow);
        
    } else if (config.type == StrategyType::RSI) {
        float *d_rsi;
        cudaMalloc(&d_rsi, mem_size);
        
        rsi_kernel<<<blocksPerGrid, threadsPerBlock>>>(d_prices, d_rsi, n, config.rsi_window);
        cudaDeviceSynchronize();

        std::vector<float> h_rsi(n);
        cudaMemcpy(h_rsi.data(), d_rsi, mem_size, cudaMemcpyDeviceToHost);
        
        effective_start = (start_pos < config.rsi_window + 1) ? config.rsi_window + 1 : start_pos;
        for (int i = effective_start; i < end_pos; ++i) {
            buy_signals[i] = (h_rsi[i-1] >= config.rsi_oversold && h_rsi[i] < config.rsi_oversold);
            sell_signals[i] = (h_rsi[i-1] <= config.rsi_overbought && h_rsi[i] > config.rsi_overbought);
        }
        
        cudaFree(d_rsi);
        
    } else if (config.type == StrategyType::MEAN_REVERSION) {
        float *d_ma, *d_upper, *d_lower;
        cudaMalloc(&d_ma, mem_size);
        cudaMalloc(&d_upper, mem_size);
        cudaMalloc(&d_lower, mem_size);
        
        bollinger_kernel<<<blocksPerGrid, threadsPerBlock>>>(d_prices, d_ma, d_upper, d_lower, n, config.bollinger_window, config.bollinger_stddev);
        cudaDeviceSynchronize();

        std::vector<float> h_upper(n), h_lower(n);
        cudaMemcpy(h_upper.data(), d_upper, mem_size, cudaMemcpyDeviceToHost);
        cudaMemcpy(h_lower.data(), d_lower, mem_size, cudaMemcpyDeviceToHost);
        
        effective_start = (start_pos < config.bollinger_window) ? config.bollinger_window : start_pos;
        for (int i = effective_start; i < end_pos; ++i) {
            buy_signals[i] = (data.close[i-1] >= h_lower[i-1] && data.close[i] < h_lower[i]);
            sell_signals[i] = (data.close[i-1] <= h_upper[i-1] && data.close[i] > h_upper[i]);
        }
        
        cudaFree(d_ma); cudaFree(d_upper); cudaFree(d_lower);
    }

    cudaFree(d_prices);

    /* 
     * OUTPUT GENERATION (Raw Parsing Engine Data)
     * Sent to stdout for the Node.js backend to capture via ChildProcess.
     *  */
    int signals = 0, look_forward = 50; 

    for (int i = effective_start; i < end_pos; ++i) {
        if (buy_signals[i] || sell_signals[i]) {
            bool buy = buy_signals[i];
            bool sell = sell_signals[i];
            
            float entry = data.close[i];
            float forward = (i + look_forward < n) ? data.close[i + look_forward] : 0.0f;
            
            std::string sig = buy ? "BUY" : "SELL";
            std::string res = "PENDING";

            if (forward > 0) {
                bool win = (buy && forward > entry) || (sell && forward < entry);
                res = win ? "PROFIT" : "LOSS";
            }

            // Raw output format for Node.js parsing:
            // "YYYY-MM-DD HH:MM:SS SIGNAL ENTRY_PRICE FWD_PRICE OUTCOME"
            std::cout << data.dates[i] << " " << sig << " " << std::fixed << std::setprecision(2) 
                      << entry << " " << forward << " " << res << std::endl;
                      
            signals++;
        }
    }
}
