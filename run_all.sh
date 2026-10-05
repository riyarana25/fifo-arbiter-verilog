#!/bin/bash
# Usage: ./run_all.sh
# 1) runs both test benches on the correct designs (must say TEST PASSED)
# 2) injects one bug at a time with -D and checks that the test bench says TEST FAILED
cd "$(dirname "$0")"
mkdir -p build
run() {  # name  defines  files...
  local name=$1 def=$2; shift 2
  iverilog -g2012 $def -o build/$name.vvp "$@" || return 2
  vvp build/$name.vvp | tee build/$name.log | grep -E "TEST (PASSED|FAILED)" | head -1
}
echo "== Correct designs =="
run fifo ""   sync_fifo.v tb_sync_fifo.v
run arb  ""   rr_arbiter.v tb_rr_arbiter.v
echo
echo "== Bug injection: every line below should say TEST FAILED =="
for b in BUG_FULL_OFF_BY_ONE BUG_NO_OVERFLOW_PROTECT BUG_SIMUL_RW; do
  printf "%-26s " $b; run fifo_$b "-D$b" sync_fifo.v tb_sync_fifo.v
done
for b in BUG_FIXED_PRIORITY BUG_GRANT_IDLE BUG_NO_ROTATE; do
  printf "%-26s " $b; run arb_$b "-D$b" rr_arbiter.v tb_rr_arbiter.v
done
