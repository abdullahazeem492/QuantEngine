#include <iostream>
#include <vector>
#include <chrono>

#ifdef MPI_AVAILABLE
#include <mpi.h>
#endif

#include "parser.hpp"
#include "simulator.hpp"

int main(int argc, char** argv) {
    int rank = 0, size = 1;

#ifdef MPI_AVAILABLE
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
#endif

    if (rank == 0) {
        std::cout << "\033[1;32m" << std::endl;
        std::cout << "  ____  _    _          _   _ _______ _____  _____   _____ " << std::endl;
        std::cout << " / __ \\| |  | |   /\\   | \\ | |__   __|  __ \\|  __ \\ / ____|" << std::endl;
        std::cout << "| |  | | |  | |  /  \\  |  \\| |  | |  | |__) | |  | | |     " << std::endl;
        std::cout << "| |  | | |  | | / /\\ \\ | . ` |  | |  |  ___/| |  | | |     " << std::endl;
        std::cout << "| |__| | |__| |/ ____ \\| |\\  |  | |  | |    | |__| | |____ " << std::endl;
        std::cout << " \\___\\_\\\\____//_/    \\_\\_| \\_|  |_|  |_|    |_____/ \\_____|" << std::endl;
        std::cout << " \033[0m" << std::endl;
        std::cout << " [MPI-0] (MASTER) quantpdc engine v1.0" << std::endl;
        std::cout << " [MPI-0] (MASTER) nodes: " << size << " | cuda: enabled" << std::endl;
        std::cout << " ------------------------------------------------------------" << std::endl;
        std::cout << " [MPI-0] (MASTER) loading bitcoin dataset..." << std::endl;
    }

    auto start_total = std::chrono::high_resolution_clock::now();

    // parsing data
    MarketData data = parse_csv("data/bitcoin_data.csv", rank);

    if (data.size > 0) {
        // calculating shards
        int shard_size = (int)data.size / size;
        int start_pos = rank * shard_size;
        int end_pos = (rank == size - 1) ? (int)data.size : (rank + 1) * shard_size;

        if (rank == 0) {
            std::cout << " [MPI-0] sharding " << data.size << " bars into " << size << " clusters." << std::endl;
        }
        
        std::cout << " [MPI-" << rank << "] processing index " << start_pos << " to " << end_pos << std::endl;

        // running simulation
        run_strategy_simulation(data, rank, start_pos, end_pos);
    }

#ifdef MPI_AVAILABLE
    MPI_Barrier(MPI_COMM_WORLD);
#endif

    auto end_total = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff = end_total - start_total;

    if (rank == 0) {
        std::cout << " ------------------------------------------------------------" << std::endl;
        std::cout << " [PERF] throughput: " << (data.size * size) / diff.count() << " bars/sec" << std::endl;
        std::cout << " [SYS] quantpdc: success." << std::endl;
    }

#ifdef MPI_AVAILABLE
    MPI_Finalize();
#endif
    return 0;
}
