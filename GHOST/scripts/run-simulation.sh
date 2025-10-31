#!/usr/bin/env bash
# run_simulation.sh: build and run Verilator sims using project Makefiles
set -euo pipefail

ALL_TESTS=(linetest linetestlite helloworld helloworldlite speechtest speechtestlite)

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -h              Show this help message and exit
  -t <tests>      Comma-separated list of tests to run (default: all)
                  Available: ${ALL_TESTS[*]}
  -p <proj_dir>   Path to project root containing top-level Makefile
  --clean         Clean all build products and exit
  --no-build      Skip building, only run existing binaries

Environment:
  VERILATOR       Path to verilator (optional; Makefiles auto-detect)
EOF
  exit 1
}

# Defaults
tests_spec=""
CLEAN=0
NO_BUILD=0
PROJ_DIR="$(pwd)"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h) usage ;;
    -t) tests_spec="$2"; shift 2 ;;
    -p) PROJ_DIR="$2"; shift 2 ;;
    --clean) CLEAN=1; shift ;;
    --no-build) NO_BUILD=1; shift ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

# Absolute path for project dir
PROJ_DIR="$(cd "$PROJ_DIR" && pwd)"


LOG_DIR="$PROJ_DIR/sim-logs"

# Sanity check
if [[ ! -f "$PROJ_DIR/Makefile" ]]; then
  echo "Error: no top-level Makefile found in $PROJ_DIR" >&2
  exit 1
fi

# Clean mode
if [[ $CLEAN -eq 1 ]]; then
  echo "=== Cleaning all build outputs in $PROJ_DIR ==="
  make -C "$PROJ_DIR/rtl" clean || true
  make -C "$PROJ_DIR/bench/verilog" clean || true
  make -C "$PROJ_DIR/bench/cpp" clean || true
  exit 0
fi

# Tests list
declare -a TESTS
if [[ -n "$tests_spec" ]]; then
  IFS=',' read -ra TESTS <<< "$tests_spec"
else
  TESTS=("${ALL_TESTS[@]}")
fi

# Validate tests
for t in "${TESTS[@]}"; do
  if [[ ! " ${ALL_TESTS[*]} " =~ " ${t} " ]]; then
    echo "Error: unknown test '${t}'. Valid: ${ALL_TESTS[*]}" >&2
    exit 1
  fi
done

# Need verilator unless skipping build
if [[ $NO_BUILD -eq 0 ]]; then
  if ! command -v "${VERILATOR:-verilator}" >/dev/null 2>&1; then
    echo "Error: verilator not found in PATH (or VERILATOR). Install it first." >&2
    exit 1
  fi
fi

mkdir -p "$LOG_DIR"

# Build if not skipped
if [[ $NO_BUILD -eq 0 ]]; then
  echo "=== Building RTL libraries (rtl) ==="
  make -C "$PROJ_DIR/rtl" test

  echo "=== Building bench Verilog libraries (bench/verilog) ==="
  make -C "$PROJ_DIR/bench/verilog" test
fi

# Build & run tests
for t in "${TESTS[@]}"; do
  if [[ $NO_BUILD -eq 0 ]]; then
    echo "=== Building $t (bench/cpp) ==="
    if ! make -C "$PROJ_DIR/bench/cpp" "$t"; then
      echo "[FAIL] Build failed for $t" >&2
      continue
    fi
  fi

  cd $PROJ_DIR/bench/cpp

  bin="$PROJ_DIR/bench/cpp/$t"
  log="$LOG_DIR/${t}.log"

  if [[ ! -x "$bin" ]]; then
    echo "[FAIL] $t: binary not found at $bin" >&2
    continue
  fi

  echo "=== Running $t ==="
  if "$bin" >"$log" 2>&1; then
    echo "[PASS] $t (log: $log)"
  else
    echo "[FAIL] $t (see log: $log)" >&2
  fi

  cd -

done

