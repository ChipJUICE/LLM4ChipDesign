# Simulation & Synthesis Automation Scripts

This repository provides two Bash scripts to automate common Verilog workflows:

1. **`run-simulation.sh`** – compile and run Icarus Verilog simulations
2. **`run-synthesis.sh`**  – synthesize designs with Yosys and a Liberty library

#### Note: These scripts are included in the Docker for the competition. As such, all prerequisites will already be installed and tested in that environment.

---

## 1. run-simulation.sh

`run-simulation.sh` automates compilation and simulation of Verilog testbenches using Icarus Verilog (`iverilog` + `vvp`). It supports flexible directory layouts, selective test execution, and centralized logging.

### Prerequisites

- Bash (POSIX-compatible)
- Icarus Verilog (`iverilog`, `vvp`) installed and on your `PATH`
- A project layout with separate directories for RTL sources and testbenches

### Features

- **Configurable directories**: Default testbench dir is `./tb`; default RTL dir is `./rtl`. Override with `-d` and `-s`.
- **Selective runs**: Specify a comma-separated list of testbench basenames with `-t`. Default: all `.v` files in the testbench directory.
- **Custom RTL inclusion**: Pick which RTL modules to compile with `-r` (comma-separated basenames). Default: all `.v` in the RTL directory.
- **Automatic outputs**:
  - Compiled executables → `./sim-run/<testbench>.out`
  - Simulation logs → `./sim-logs/<testbench>.log`
- **Pass/fail reporting**: Terminal output indicates success or failure per test.

### Usage

```bash
# Show detailed help
./run_simulation.sh -h

# Run every testbench in ./tb/ with all RTL in ./rtl/
./run_simulation.sh

# Run specific benches (aes and aes_core) against default RTL
./run_simulation.sh -t aes,aes_core

# Use custom directories
tb_dir="my_projects/bench_tb"; rtl_dir="my_projects/rtl_src"
./run_simulation.sh -d "$tb_dir" -s "$rtl_dir"

# Specify both tests and RTL modules
tb_list="tb_aes_key_mem"; rtl_list="aes_core,aes_sbox"
./run_simulation.sh -t "$tb_list" -r "$rtl_list"
```

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

# Synthesize only aes_core and aes_sbox with custom Liberty
./run_synthesis.sh -p <../01_easy> -i aes_core,aes_sbox -l path/to/custom.lib

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

