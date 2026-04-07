#include "parser.hpp"
#include <chrono>
#include <cmath>
#include <fstream>
#include <sstream>

#ifdef _OPENMP
#include <omp.h>
#endif

// Parses a CSV file into a MarketData Structure of Arrays (SoA)
MarketData parse_csv(const std::string &filename, int rank) {
  MarketData data;
  std::ifstream file(filename);
  if (!file.is_open())
    return data;

  std::vector<std::string> lines;
  std::string line;

  // Read all lines into memory
  while (std::getline(file, line)) {
    if (!line.empty())
      lines.push_back(line);
  }
  file.close();

  size_t num_lines = lines.size();
  if (num_lines == 0)
    return data;

  // Skip headers and dummy rows (start at index 2)
  size_t start_idx = 2;
  size_t count = num_lines - start_idx;

  // Allocate memory for the SoA
  data.dates.resize(count);
  data.timestamps.resize(count);
  data.open.resize(count);
  data.high.resize(count);
  data.low.resize(count);
  data.close.resize(count);
  data.volume.resize(count);
  data.size = count;

  /* 
   * OpenMP Parallel For Loop
   * 
   * This directive instructs the compiler to divide the loop iterations 
   * across multiple CPU threads. Since parsing independent CSV rows has 
   * no data dependencies, it is perfectly suited for multi-core parallelism.
   */
  #pragma omp parallel for
  for (long long i = (long long)start_idx; i < (long long)num_lines; ++i) {
    const std::string &row = lines[i];
    size_t idx = (size_t)(i - start_idx);
    std::stringstream ss(row);
    std::string token;

    // Unix Timestamp
    std::getline(ss, token, ',');
    try {
      data.timestamps[idx] = std::stoll(token);
    } catch (...) {
      data.timestamps[idx] = 0;
    }
    
    // Human-readable Date
    std::getline(ss, data.dates[idx], ',');
    
    // Symbol (skipped, handled by backend)
    std::getline(ss, token, ','); 
    
    // Open, High, Low, Close, Volume
    // Using std::stof for simple, readable float parsing
    std::getline(ss, token, ',');
    data.open[idx] = std::stof(token);
    
    std::getline(ss, token, ',');
    data.high[idx] = std::stof(token);
    
    std::getline(ss, token, ',');
    data.low[idx] = std::stof(token);
    
    std::getline(ss, token, ',');
    data.close[idx] = std::stof(token);
    
    std::getline(ss, token, ',');
    data.volume[idx] = std::stof(token);
  }

  return data;
}
