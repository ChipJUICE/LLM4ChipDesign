#!/usr/bin/env bash
# run_simulation.sh: compile and run AES testbenches with iverilog

set -euo pipefail

# Default directories and output locations
TB_DIR="./tb"
RTL_DIR="./rtl"
LOG_DIR="./sim-logs"
SIM_RUN_DIR="./sim-run"

usage() {
  cat <<EOF
Usage: $0 [-h] [-d tb_dir] [-s rtl_dir] [-t test1,test2,...] [-r rtl1,rtl2,...]

Options:
  -h            Show this help message and exit
  -d <tb_dir>   Directory containing testbenches (default: ./tb)
  -s <rtl_dir>  Directory containing RTL sources (default: ./rtl)
  -t <tests>    Comma-separated list of testbench basenames (without .v). Default: all in tb_dir
  -r <rtls>     Comma-separated list of RTL basenames (without .v). Default: all in rtl_dir
EOF
  exit 1
}

# Parse flags
tests_spec=""
rtl_spec=""
while getopts ":hd:s:t:r:" opt; do
  case "$opt" in
    h) usage ;;
    d) TB_DIR="$OPTARG" ;;
    s) RTL_DIR="$OPTARG" ;;
    t) tests_spec="$OPTARG" ;;
    r) rtl_spec="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND -1))

# Build list of testbench files
declare -a tests
if [[ -n "$tests_spec" ]]; then
  IFS=',' read -ra names <<< "$tests_spec"
  for name in "${names[@]}"; do
    file="$TB_DIR/${name%.v}.v"
    if [[ ! -f "$file" ]]; then
      echo "Error: testbench '$file' not found." >&2
      exit 1
    fi
    tests+=("$file")
  done
else
  tests=("$TB_DIR"/*.v)
fi

# Build list of RTL source files
declare -a rtl_sources
if [[ -n "$rtl_spec" ]]; then
  IFS=',' read -ra names <<< "$rtl_spec"
  for name in "${names[@]}"; do
    file="$RTL_DIR/${name%.v}.v"
    if [[ ! -f "$file" ]]; then
      echo "Error: RTL source '$file' not found." >&2
      exit 1
    fi
    rtl_sources+=("$file")
  done
else
  rtl_sources=("$RTL_DIR"/*.v)
fi

# Prepare output directories
mkdir -p "$LOG_DIR" "$SIM_RUN_DIR"

# Compile and simulate each testbench
for tb in "${tests[@]}"; do
  tb_base=$(basename "$tb" .v)
  exe="$SIM_RUN_DIR/${tb_base}.out"

  echo "Compiling $tb_base from \${rtl_sources[*]} + $tb..."
  if ! iverilog -o "$exe" "${rtl_sources[@]}" "$tb"; then
    echo "[FAIL] Compilation failed for $tb_base" >&2
    continue
  fi

  echo "Running $tb_base..."
  if vvp "$exe" > "$LOG_DIR/${tb_base}.log" 2>&1; then
    echo "[PASS] $tb_base (log: $LOG_DIR/${tb_base}.log)"
  else
    echo "[FAIL] Simulation failed for $tb_base (see log: $LOG_DIR/${tb_base}.log)" >&2
  fi

done

