#ifndef QUANTPDC_PARSER_HPP
#define QUANTPDC_PARSER_HPP

#include <string>
#include <vector>

// Structure of Arrays (SoA) layout for high-performance GPU access
struct MarketData {
    std::vector<std::string> dates; // Human-readable dates
    std::vector<long long> timestamps; 
    std::vector<float> open;
    std::vector<float> high;
    std::vector<float> low;
    std::vector<float> close;
    std::vector<float> volume;
    size_t size = 0;
};

MarketData parse_csv(const std::string& filename, int rank);

#endif // PARSER_HPP
