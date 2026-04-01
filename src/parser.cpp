#include "parser.hpp"
#include <chrono>
#include <cmath>
#include <fstream>
#include <iostream>
#include <sstream>

#ifdef _OPENMP
#include <omp.h>
#endif

// fast string to float
inline float fast_atof(const char *p) {
  float r = 0.0f;
  bool neg = false;
  if (*p == '-') {
    neg = true;
    ++p;
  }
  while (*p >= '0' && *p <= '9') {
    r = (r * 10.0f) + (*p - '0');
    ++p;
  }
  if (*p == '.') {
    float f = 0.0f;
    int n = 0;
    ++p;
    while (*p >= '0' && *p <= '9') {
      f = (f * 10.0f) + (*p - '0');
      ++p;
      ++n;
    }
    r += f / std::pow(10.0f, n);
  }
  if (*p == 'e' || *p == 'E') {
    ++p;
    int e = 0;
    bool eneg = false;
    if (*p == '-') {
      eneg = true;
      ++p;
    } else if (*p == '+') {
      ++p;
    }
    while (*p >= '0' && *p <= '9') {
      e = (e * 10) + (*p - '0');
      ++p;
    }
    r *= std::pow(10.0f, eneg ? -e : e);
  }
  return neg ? -r : r;
}

MarketData parse_csv(const std::string &filename, int rank) {
  MarketData data;
  std::ifstream file(filename);
  if (!file.is_open())
    return data;

  std::vector<std::string> lines;
  std::string line;

  // loading lines
  while (std::getline(file, line)) {
    if (!line.empty())
      lines.push_back(line);
  }
  file.close();

  size_t num_lines = lines.size();
  if (num_lines == 0)
    return data;

  size_t start_idx = 2;
  size_t count = num_lines - start_idx;

  if (rank == 0) {
#ifdef _OPENMP
    std::cout << " [PARS] openmp: parsing " << count << " rows." << std::endl;
#endif
  }

  data.dates.resize(count);
  data.timestamps.resize(count);
  data.open.resize(count);
  data.high.resize(count);
  data.low.resize(count);
  data.close.resize(count);
  data.volume.resize(count);
  data.size = count;

// parallel parse
#pragma omp parallel for
  for (long long i = (long long)start_idx; i < (long long)num_lines; ++i) {
    const std::string &row = lines[i];
    size_t idx = (size_t)(i - start_idx);
    std::stringstream ss(row);
    std::string token;

    std::getline(ss, token, ',');
    try {
      data.timestamps[idx] = std::stoll(token);
    } catch (...) {
      data.timestamps[idx] = 0;
    }
    std::getline(ss, data.dates[idx], ',');
    std::getline(ss, token, ','); // symbol
    std::getline(ss, token, ',');
    data.open[idx] = fast_atof(token.c_str());
    std::getline(ss, token, ',');
    data.high[idx] = fast_atof(token.c_str());
    std::getline(ss, token, ',');
    data.low[idx] = fast_atof(token.c_str());
    std::getline(ss, token, ',');
    data.close[idx] = fast_atof(token.c_str());
    std::getline(ss, token, ',');
    data.volume[idx] = fast_atof(token.c_str());
  }

  return data;
}
