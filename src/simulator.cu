#include <iostream>
#include <vector>
#include <iomanip>
#include <sstream>
#include <cuda_runtime.h>
#include <math.h>

#include "parser.hpp"
#include "simulator.hpp"
#include "config.hpp"

// 1. Golden Cross Kernel
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

// 2. RSI Kernel
__global__ void rsi_kernel(float* prices, float* rsi, int n, int window) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        if (i < window) {
            rsi[i] = 50.0f; // Neutral before enough data
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

// 3. Bollinger Bands (Mean Reversion) Kernel
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

void run_strategy_simulation(const MarketData& data, const StrategyConfig& config, int rank, int start_pos, int end_pos) {
    if (data.size == 0) return;

    int n = (int)data.size;
    float *d_prices;
    size_t mem_size = n * sizeof(float);
    
    cudaMalloc(&d_prices, mem_size);
    cudaMemcpy(d_prices, data.close.data(), mem_size, cudaMemcpyHostToDevice);

    int threadsPerBlock = 256;
    int blocksPerGrid = (n + threadsPerBlock - 1) / threadsPerBlock;
    
    std::vector<bool> buy_signals(n, false);
    std::vector<bool> sell_signals(n, false);
    int effective_start = start_pos;

    if (config.type == StrategyType::GOLDEN_CROSS) {
        float *d_fast, *d_slow;
        cudaMalloc(&d_fast, mem_size);
        cudaMalloc(&d_slow, mem_size);
        
        golden_cross_kernel<<<blocksPerGrid, threadsPerBlock>>>(d_prices, d_fast, d_slow, n, config.fast_window, config.slow_window);
        cudaDeviceSynchronize();

        std::vector<float> h_fast(n), h_slow(n);
        cudaMemcpy(h_fast.data(), d_fast, mem_size, cudaMemcpyDeviceToHost);
        cudaMemcpy(h_slow.data(), d_slow, mem_size, cudaMemcpyDeviceToHost);
        
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
            buy_signals[i] = (h_rsi[i-1] >= config.rsi_oversold && h_rsi[i] < config.rsi_oversold); // crosses below oversold
            sell_signals[i] = (h_rsi[i-1] <= config.rsi_overbought && h_rsi[i] > config.rsi_overbought); // crosses above overbought
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
            // Price drops below lower band (Buy), Price goes above upper band (Sell)
            buy_signals[i] = (data.close[i-1] >= h_lower[i-1] && data.close[i] < h_lower[i]);
            sell_signals[i] = (data.close[i-1] <= h_upper[i-1] && data.close[i] > h_upper[i]);
        }
        
        cudaFree(d_ma); cudaFree(d_upper); cudaFree(d_lower);
    }

    cudaFree(d_prices);

    // trading dashboard
    std::stringstream log;
    log << "\n \033[1;33m[NODE-" << rank << " DASHBOARD: " << config.name << "]\033[0m" << std::endl;
    log << " " << std::string(95, '-') << std::endl;
    log << " " << std::left << std::setw(20) << "TIMESTAMP" << std::setw(12) << "SIGNAL" 
        << std::setw(15) << "ENTRY" << std::setw(15) << "FWD-50" << std::setw(15) << "VALIDATE" << "OUTCOME" << std::endl;
    log << " " << std::string(95, '-') << std::endl;

    int signals = 0, correct = 0, look_forward = 50; 

    for (int i = effective_start; i < end_pos; ++i) {
        if (buy_signals[i] || sell_signals[i]) {
            bool buy = buy_signals[i];
            bool sell = sell_signals[i];
            
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
    } else {
        std::cout << log.str() << " [MPI-" << rank << "] no signals generated." << std::endl;
    }
}
