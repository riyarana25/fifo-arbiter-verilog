# Synchronous FIFO + Round-Robin Arbiter

Two small, self-checking Verilog designs, built to practice RTL design and testbench writing.

## Designs

- **`sync_fifo.v`** — 8-bit wide, 16-entry deep synchronous FIFO with `full`, `empty`, overflow, and underflow flags.
- **`rr_arbiter.v`** — 4-requester round-robin arbiter.

## Testbenches

- **`tb_sync_fifo.v`** — self-checking against a reference model (a simple queue), reports `TEST PASSED`/`TEST FAILED`.
- **`tb_rr_arbiter.v`** — checks four correctness properties every cycle (one-hot grant, grant implies request, fairness/rotation, no grant when idle).

## Running it

Requires [Icarus Verilog](https://bleyer.org/icarus/).

```bash
./run_all.sh
```

This runs both testbenches against the correct RTL (should print `TEST PASSED`), then re-runs them six times with a bug injected via `` `define `` flags (`BUG_FULL_OFF_BY_ONE`, `BUG_NO_OVERFLOW_PROTECT`, `BUG_SIMUL_RW`, `BUG_FIXED_PRIORITY`, `BUG_GRANT_IDLE`, `BUG_NO_ROTATE`) — each of those should print `TEST FAILED`, confirming the checkers actually catch bugs.

## Scope

This is RTL-level verification with directed/self-checking testbenches in plain Verilog. It does not include SVA, UVM, functional coverage, or an FPGA build — none of that is claimed here.
