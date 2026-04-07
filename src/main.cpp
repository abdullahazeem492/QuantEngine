#include <iostream>
#include <vector>
#include <chrono>
#include <string>

#ifdef MPI_AVAILABLE
#include <mpi.h>
#endif

#include "parser.hpp"
#include "simulator.hpp"
#include "config.hpp"

// Simple CLI Parser
StrategyConfig parse_cli_args(int argc, char** argv) {
    StrategyConfig config;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--strategy" && i + 1 < argc) {
            std::string strat = argv[++i];
            if (strat == "golden_cross") { config.type = StrategyType::GOLDEN_CROSS; config.name = "Golden Cross"; }
            else if (strat == "rsi") { config.type = StrategyType::RSI; config.name = "RSI"; }
            else if (strat == "mean_reversion") { config.type = StrategyType::MEAN_REVERSION; config.name = "Mean Reversion"; }
        }
        else if (arg == "--fast-window" && i + 1 < argc) config.fast_window = std::stoi(argv[++i]);
        else if (arg == "--slow-window" && i + 1 < argc) config.slow_window = std::stoi(argv[++i]);
        else if (arg == "--rsi-window" && i + 1 < argc) config.rsi_window = std::stoi(argv[++i]);
        else if (arg == "--rsi-overbought" && i + 1 < argc) config.rsi_overbought = std::stof(argv[++i]);
        else if (arg == "--rsi-oversold" && i + 1 < argc) config.rsi_oversold = std::stof(argv[++i]);
        else if (arg == "--bb-window" && i + 1 < argc) config.bollinger_window = std::stoi(argv[++i]);
        else if (arg == "--bb-stddev" && i + 1 < argc) config.bollinger_stddev = std::stof(argv[++i]);
        else if (arg == "--data" && i + 1 < argc) config.data_path = argv[++i];
    }
    return config;
}

int main(int argc, char** argv) {
    int rank = 0, size = 1;

    /* 
     * MPI Initialization
     * MPI (Message Passing Interface) allows us to run multiple instances 
     * of this program across different CPU cores or even different physical 
     * machines.
     * 
     * 'size' = Total number of processes in the cluster.
     * 'rank' = The unique ID of *this* specific process (0 to size-1).
     */
#ifdef MPI_AVAILABLE
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
#endif

    StrategyConfig config = parse_cli_args(argc, argv);
    auto start_total = std::chrono::high_resolution_clock::now();

    // 1. All nodes parse the CSV into memory.
    MarketData data = parse_csv(config.data_path, rank);

    if (data.size > 0) {
        /*
         * MPI Data Sharding
         * Instead of every node processing the entire dataset, we divide 
         * the dataset into equally sized 'shards'.
         * Node 0 processes the first chunk, Node 1 the second, and so on.
         * This allows horizontal scaling of the workload.
         */
        int shard_size = (int)data.size / size;
        int start_pos = rank * shard_size;
        int end_pos = (rank == size - 1) ? (int)data.size : (rank + 1) * shard_size;

        // 2. Each node runs the CUDA simulation on its specific shard.
        run_strategy_simulation(data, config, rank, start_pos, end_pos);
    }

#ifdef MPI_AVAILABLE
    // Wait for all nodes to finish their shard before calculating final metrics.
    MPI_Barrier(MPI_COMM_WORLD);
#endif

    auto end_total = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff = end_total - start_total;

    // Rank 0 (Master) outputs the final system performance metric.
    if (rank == 0) {
        std::cout << "throughput: " << (data.size * size) / diff.count() << " bars/sec" << std::endl;
    }

#ifdef MPI_AVAILABLE
    MPI_Finalize();
#endif
    return 0;
}
