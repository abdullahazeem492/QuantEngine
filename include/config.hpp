#ifndef QUANTPDC_CONFIG_HPP
#define QUANTPDC_CONFIG_HPP

#include <string>
#include <map>

enum class StrategyType {
    GOLDEN_CROSS,
    RSI,
    MEAN_REVERSION
};

struct StrategyConfig {
    StrategyType type;
    std::string name;

    // Parameters for tuning
    int fast_window;
    int slow_window;
    int rsi_window;
    float rsi_overbought;
    float rsi_oversold;
    int bollinger_window;
    float bollinger_stddev;

    StrategyConfig() {
        // Defaults
        type = StrategyType::GOLDEN_CROSS;
        name = "Golden Cross";
        fast_window = 50;
        slow_window = 200;
        rsi_window = 14;
        rsi_overbought = 70.0f;
        rsi_oversold = 30.0f;
        bollinger_window = 20;
        bollinger_stddev = 2.0f;
    }
};

#endif // QUANTPDC_CONFIG_HPP
