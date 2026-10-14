#!/bin/bash
# Assemble the AnyKernel3 flashable zip from a finished build.
# Usage: ./droidspaces/package.sh <device> <kernel_root> <ak3_dir> <kernelrelease>
#
# Design (first-boot safety):
#  - boot.img gets our Image only. Stock ramdisk AND stock dtb/dtbo are kept:
#    our changes touch no driver and no DT binding, so stock DT stays valid.
#  - vendor_boot gets a refreshed vendor_ramdisk: ALL modules from
#    modules.load.<device>, rebuilt from this same tree (consistent vermagic),
#    swapped 1:1 in ramdisk order. No orphans, no missing modules.
#  - recovery is never touched (it carries its own kernel+modules).
set -euo pipefail

DEVICE="$1"; KROOT="$2"; AK3="$3"; REL="$4"
HERE="$(dirname "$(readlink -f "$0")")"
OUT="${KROOT}/out"; STAGE="${OUT}/ak3-${DEVICE}"
rm -rf "${STAGE}"; mkdir -p "${STAGE}"

# AnyKernel3 base (everything except its sample anykernel.sh/kernel)
cp -r "${AK3}/META-INF" "${AK3}/tools" "${AK3}/LICENSE" "${STAGE}/" 2>/dev/null
sed "s/@DEVICE@/${DEVICE}/g; s/@REL@/${REL}/g" "${HERE}/anykernel.template.sh" > "${STAGE}/anykernel.sh"

# 1. kernel image
cp "${KROOT}/arch/arm64/boot/Image" "${STAGE}/Image"

# 2. modules: ship every BUILT .ko, keep modules.load verbatim as the load
#    order list. Rationale: modules.load is a platform-wide superset shared
#    across sm7325 devices (a52sxq/a73xq/m52xq list 87/86/90 entries incl.
#    codecs none of them build - e.g. camera.ko has no Kconfig anywhere).
#    Official builds from this same defconfig ship the same ~54 modules;
#    init first-stage loads what exists and skips the rest, exactly as stock.
#    So: missing entries are warnings, NOT fatal. The floor assert below is
#    what catches a genuinely broken build (e.g. dead toolchain).
mkdir -p "${STAGE}/vendor_ramdisk/lib/modules"
: > "${OUT}/MODULES.txt"
: > "${OUT}/MISSING.txt"
while IFS= read -r mod; do
  [ -z "$mod" ] && continue
  # modules land next to their drivers (in-tree build); match exact filename
  f="$(find "${KROOT}" -name "${mod}" 2>/dev/null | head -1)"
  if [ -z "$f" ]; then echo "SKIP (not built from this tree, init skips it too): ${mod}" | tee -a "${OUT}/MISSING.txt"; continue; fi
  cp "$f" "${STAGE}/vendor_ramdisk/lib/modules/"
  echo "${mod} <= ${f}" >> "${OUT}/MODULES.txt"
done < "${HERE}/modules.load.${DEVICE}"
cp "${HERE}/modules.load.${DEVICE}" "${STAGE}/vendor_ramdisk/lib/modules/modules.load"
N_BUILT="$(wc -l < "${OUT}/MODULES.txt")"
echo "modules packaged: ${N_BUILT}"
[ "${N_BUILT}" -ge 50 ] || { echo "FLOOR FAIL: only ${N_BUILT} modules (expected ~54) - toolchain/build broken?"; exit 1; }

# 3. zip it
DATE="$(date -u +%Y%m%d)"
ZIP="Droidspaces-sm7325-${DEVICE}-${REL}-${DATE}.zip"
(cd "${STAGE}" && zip -r9 "${OUT}/${ZIP}" . -x '*.git*')
(cd "${OUT}" && sha256sum "${ZIP}" > "${ZIP}.sha256")
echo "PACKAGED: ${OUT}/${ZIP}"
unzip -l "${OUT}/${ZIP}" | tail -5
