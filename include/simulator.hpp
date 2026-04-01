#ifndef QUANTPDC_SIMULATOR_HPP
#define QUANTPDC_SIMULATOR_HPP

#include "parser.hpp"
#include "config.hpp"

void run_strategy_simulation(const MarketData& data, const StrategyConfig& config, int rank, int start_pos, int end_pos);

#endif // SIMULATOR_HPP
