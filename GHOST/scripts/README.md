# Simulation & Synthesis Automation Scripts

This repository provides two Bash scripts to automate common Verilog workflows:

1. **`run-simulation.sh`** – compile and run Verilator simulations
2. **`run-synthesis.sh`**  – synthesize designs with Yosys and a Liberty library

#### Note: These scripts are included in the Docker for the competition. As such, all prerequisites will already be installed and tested in that environment.

---

## 1. run-simulation.sh

`run-simulation.sh` automates compilation and simulation of Verilog testbenches Verilator. It supports flexible directory layouts, selective test execution, and centralized logging.

### Prerequisites

- Bash (POSIX-compatible)
- Verilator installed and on your `PATH`
- A project with the following layout:
```
<project>/
├── Makefile
├── rtl/ # simulateable RTL
└── bench/
    ├── verilog/ # Verilog testbenches for Verilator
    └── cpp/ # C++ harnesses and test executables for Verilator
```

### Features

- **Project root selection**: Use `-p` to point to the project root containing the top-level Makefile. Defaults to current directory.
- **Selective runs**: Run specific tests with `-t` (comma-separated). Defaults to all known tests.
- **Log capture**: Each test’s output is written to `./sim-logs/<test>.log`.
- **Pass/fail reporting**: Results are printed to the terminal.
- **Clean rebuilds**: `--clean` removes all build artifacts across `rtl`, `bench/verilog`, and `bench/cpp`.
- **Run without rebuilding**: `--no-build` skips compilation and only executes already-built binaries.

### Supported Tests

The available test executables (from `bench/cpp/Makefile`) are:

- `linetest`
- `linetestlite`
- `helloworld`
- `helloworldlite`
- `speechtest`
- `speechtestlite`

### Usage

```bash
# Show detailed help
./run_simulation.sh -h

# Run all tests from a project in ./wbuart32
./run_simulation.sh -p ./wbuart32

# Run only linetest and helloworld
./run_simulation.sh -p ./wbuart32 -t linetest,helloworld

# Clean all build products
./run_simulation.sh -p ./wbuart32 --clean

# Skip building and only run already-built binaries
./run_simulation.sh -p ./wbuart32 --no-build -t speechtest

### Output Layout

- **`sim-run/`**: Contains compiled `.out` binaries for each testbench.
- **`sim-logs/`**: Contains `<testbench>.log` files capturing `vvp` output (stdout+stderr).

---

## 2. run-synthesis.sh

`run-synthesis.sh` automates synthesis of Verilog designs with Yosys, mapping to a specified Liberty library and producing gate-level netlists plus JSON reports.

### Prerequisites

- Bash (POSIX-compatible)
- Yosys installed and on your `PATH`
- A Liberty `.lib` file for your target library
- RTL source files to synthesize

### Features

- **Configurable RTL directory**: Default `./rtl`, override with `-d`.
- **Module selection**: Choose which Verilog files to include via `-i` (comma-separated basenames). Default: all `.v` in RTL dir.
- **Liberty file**: Specify `.lib` path with `-l` (default: `./rtl/synth/sky130_fd_sc_hd__tt_025C_1v80.lib`).
- **Top module override**: Use `-m` to set the top-level entity (default: `aes`).
- **Clock period target**: Set for slack analysis via `-c` (in ps, default: `1000`).
- **Output directories**: Gate-level Verilog & JSON → `./synth-run`; logs → `./synth-logs`. Both can be changed with `-o` and `-L`.
- **Logging**: Full Yosys console output captured per run.

### Usage
Default project is `./`, to run from this directory on a specific challenge project, you need to supply `-p <../challenge>` for the correct project (i.e. `-p ../01_easy`).

```bash
# Show detailed help
./run_synthesis.sh -h

# Default synthesis (all RTL, default lib)
./run_synthesis.sh -p ../01_easy

# Synthesize only rxuart with custom Liberty
./run_synthesis.sh -p ../01_easy -i rxuart -l path/to/custom.lib

# Custom RTL directory and output locations
./run_synthesis.sh -d src/rtl -o build/netlist -L build/logs

# Override top module and clock period
./run_synthesis.sh -m my_top -c 500
```

### Output Layout

- **`synth-run/`**: Contains `<top>_synth.v` (netlist) and `<top>_synth.json` (report).
- **`synth-logs/`**: Contains `<top>_synth.log` with full Yosys output.

---

## Notes

- Ensure both scripts are executable:
  ```bash
  chmod +x run_simulation.sh run_synthesis.sh
  ```
- Existing files in the `*-run/` and `*-logs/` directories will be overwritten on reruns.
- Missing inputs (testbench, RTL, or Liberty) will cause an early error.

