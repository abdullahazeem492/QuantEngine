cmake_minimum_required(VERSION 3.18)
project(quantpdc LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find MPI (Distributed Cluster)
find_package(MPI)
if(MPI_FOUND)
    include_directories(${MPI_CXX_INCLUDE_PATH})
endif()

# Find OpenMP (CPU Multi-threading) 
# Note: Using COMPONENTS CXX because CUDA/NVCC does not use OpenMP directly in our pipeline
find_package(OpenMP COMPONENTS CXX)

# CUDA architectures
set(CMAKE_CUDA_ARCHITECTURES 75 80 86 89)

include_directories(${CMAKE_SOURCE_DIR}/include)

set(SOURCES
    src/main.cpp
    src/parser.cpp
    src/simulator.cu
)

add_executable(${PROJECT_NAME} ${SOURCES})

# MPI Linking
if(MPI_FOUND)
    target_link_libraries(${PROJECT_NAME} PRIVATE MPI::MPI_CXX)
    target_compile_definitions(${PROJECT_NAME} PRIVATE MPI_AVAILABLE)
endif()

# OpenMP Linking
if(OpenMP_CXX_FOUND)
    target_link_libraries(${PROJECT_NAME} PRIVATE OpenMP::OpenMP_CXX)
    target_compile_definitions(${PROJECT_NAME} PRIVATE _OPENMP)
else()
    message(WARNING "OpenMP (CXX) not found! CPU Multi-threading will be limited.")
endif()
