# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains whisper.cpp, a high-performance inference implementation of OpenAI's Whisper automatic speech recognition (ASR) model. It's written in C/C++ with no external dependencies and supports various hardware acceleration options.

Key features:
- Plain C/C++ implementation without dependencies
- Optimized for Apple Silicon (ARM NEON, Accelerate framework, Metal, Core ML)
- AVX intrinsics support for x86 architectures
- Support for CPU-only inference and various GPU backends (NVIDIA, Vulkan, etc.)
- Zero memory allocations at runtime
- C-style API in whisper.h

## Common Development Commands

### Building the Project
```bash
# Basic build
cmake -B build
cmake --build build -j --config Release

# Build with specific optimizations
cmake -B build -DGGML_CUDA=1          # For NVIDIA GPU support
cmake -B build -DWHISPER_COREML=1     # For Apple Core ML support
cmake -B build -DGGML_VULKAN=1        # For Vulkan GPU support
cmake -B build -DGGML_BLAS=1          # For OpenBLAS CPU acceleration
```

### Running the Main CLI Tool
```bash
# Download a model
./models/download-ggml-model.sh base.en

# Transcribe an audio file
./build/bin/whisper-cli -f samples/jfk.wav

# With specific model
./build/bin/whisper-cli -m models/ggml-base.en.bin -f samples/jfk.wav
```

### Quick Demo
```bash
make base.en  # Downloads model and runs inference on samples
```

### Docker Usage
```bash
# Download model and persist it in a local folder
docker run -it --rm -v path/to/models:/models whisper.cpp:main "./models/download-ggml-model.sh base /models"

# Transcribe an audio file
docker run -it --rm -v path/to/models:/models -v path/to/audios:/audios whisper.cpp:main "whisper-cli -m /models/ggml-base.bin -f /audios/jfk.wav"
```

## Testing

### Running Benchmarks
```bash
# Benchmark the encoder performance
./build/bin/whisper-bench -m models/ggml-base.en.bin

# Run comprehensive benchmarks with different thread counts
python3 scripts/bench.py -f samples/jfk.wav -t 2,4,8 -p 1,2
```

### Integration Tests
```bash
# Run integration tests for a specific model
./tests/run-tests.sh base.en
```

## Code Architecture

The codebase is organized as follows:

### Core Components
- `whisper.h` - Main C API header with comprehensive documentation
- `src/whisper.cpp` - Main implementation
- `ggml/` - Machine learning library used for tensor operations
- `examples/` - Various usage examples including CLI, server, streaming, etc.
- `models/` - Model conversion scripts and download utilities

### Key API Patterns
The main usage pattern involves:
1. Initialize context with `whisper_init_from_file_with_params()`
2. Process audio with `whisper_full()` or step-by-step with `whisper_pcm_to_mel()`, `whisper_encode()`, `whisper_decode()`
3. Extract results with `whisper_full_n_segments()` and `whisper_full_get_segment_text()`
4. Clean up with `whisper_free()`

### Supported Hardware Backends
- CPU (optimized with BLAS, OpenMP)
- NVIDIA GPU (CUDA)
- Apple Silicon (Metal, Core ML)
- Vulkan
- OpenVINO
- Ascend NPU
- Moore Threads GPU

The implementation automatically selects the best available backend based on compilation flags and runtime detection.