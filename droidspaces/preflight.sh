#!/bin/bash
# Preflight: assert the Droidspaces flag set resolved correctly in .config.
# Usage: ./droidspaces/preflight.sh <device>   (run after defconfig+olddefconfig)
# Fails the CI job (or your local build) before the expensive compile starts.
set -euo pipefail

DEVICE="${1:?usage: preflight.sh <a52sxq|a73xq|m52xq>}"
[ -f .config ] || { echo "no .config - run defconfig first"; exit 1; }

MUST_Y=(
  SYSVIPC POSIX_MQUEUE IPC_NS PID_NS DEVTMPFS
  NETFILTER_XT_MATCH_ADDRTYPE USER_NS IP6_NF_NAT IP6_NF_TARGET_MASQUERADE
  MACVLAN NETFILTER_XT_TARGET_LOG NETFILTER_XT_MATCH_RECENT
  IP_SET IP_SET_HASH_IP IP_SET_HASH_NET NETFILTER_XT_SET
  TMPFS_POSIX_ACL TMPFS_XATTR
)
# Deliberately off: the two kABI-breakers from the doc's CPU/process-limits
# section (no padding trick covers them - would bootloop on stock modules).
MUST_OFF=( CFS_BANDWIDTH CGROUP_PIDS )

fail=0
for k in "${MUST_Y[@]}"; do
  grep -q "^CONFIG_${k}=y$" .config || { echo "MISSING/WARN: CONFIG_${k} is not =y"; fail=1; }
done
for k in "${MUST_OFF[@]}"; do
  if grep -q "^CONFIG_${k}=" .config; then echo "MUST-STAY-OFF VIOLATION: CONFIG_${k}"; fail=1; fi
done
# REJECT target does not exist on 5.4 (covered by IP_NF/IP6_NF_TARGET_REJECT,
# both already =y in these trees) - assert the equivalents instead.
for k in IP_NF_TARGET_REJECT IP6_NF_TARGET_REJECT; do
  grep -q "^CONFIG_${k}=y$" .config || { echo "MISSING: CONFIG_${k}=y"; fail=1; }
done

if [ "$fail" -ne 0 ]; then echo "PREFLIGHT FAILED"; exit 1; fi
echo "PREFLIGHT OK (${#MUST_Y[@]} flags =y, ${#MUST_OFF[@]} breakers off) for ${DEVICE}"
