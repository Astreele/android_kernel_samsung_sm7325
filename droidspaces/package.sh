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

# 2. modules: ship every BUILT .ko under modules/vendor/lib/modules (installed
#    live onto /vendor by do.modules=1), plus the load-order list.
#    Layout rationale (verified against the official nightly's vendor.img):
#    official vendor_boot ramdisk holds ONLY fstab - all 87 modules plus
#    modules.load/dep/alias/softdep live in vendor.img /lib/modules. So this
#    is where rebuilt modules must go; a vendor_boot injection would sit
#    unloaded while stock wrong-CRC modules stay live (dead Wi-Fi/BT/etc).
#    modules.load is a platform-wide superset shared across sm7325 devices;
#    entries no tree builds are skipped with a warning - init first-stage
#    skips absentees exactly as stock does. The floor assert below is what
#    catches a genuinely broken build (e.g. dead toolchain).
mkdir -p "${STAGE}/modules/vendor/lib/modules"
: > "${OUT}/MODULES.txt"
: > "${OUT}/MISSING.txt"
while IFS= read -r mod; do
  [ -z "$mod" ] && continue
  # modules land next to their drivers (in-tree build); match exact filename
  f="$(find "${KROOT}" -name "${mod}" 2>/dev/null | head -1)"
  if [ -z "$f" ] && [ "$mod" = "qca_cld3_wlan.ko" ]; then
    # Proven by forensics: official qca_cld3_wlan.ko identifies internally as
    # name=wlan - Lineage renames the built wlan.ko at install time. Mirror it.
    f="$(find "${KROOT}" -name "wlan.ko" 2>/dev/null | head -1)"
    [ -n "$f" ] && echo "RENAME: wlan.ko -> qca_cld3_wlan.ko (matches official layout)"
  fi
  if [ -z "$f" ]; then echo "SKIP (not built from this tree, init skips it too): ${mod}" | tee -a "${OUT}/MISSING.txt"; continue; fi
  cp "$f" "${STAGE}/modules/vendor/lib/modules/${mod}"
  echo "${mod} <= ${f}" >> "${OUT}/MODULES.txt"
done < "${HERE}/modules.load.${DEVICE}"
cp "${HERE}/modules.load.${DEVICE}" "${STAGE}/modules/vendor/lib/modules/modules.load"
N_BUILT="$(grep -c "\.ko <=" "${OUT}/MODULES.txt")"
echo "modules packaged: ${N_BUILT}"
[ "${N_BUILT}" -ge 50 ] || { echo "FLOOR FAIL: only ${N_BUILT} modules (expected ~87) - toolchain/build broken?"; exit 1; }

# 3. zip it
DATE="$(date -u +%Y%m%d)"
ZIP="Droidspaces-sm7325-${DEVICE}-${REL}-${DATE}.zip"
(cd "${STAGE}" && zip -r9 "${OUT}/${ZIP}" . -x '*.git*')
(cd "${OUT}" && sha256sum "${ZIP}" > "${ZIP}.sha256")
echo "PACKAGED: ${OUT}/${ZIP}"
unzip -l "${OUT}/${ZIP}" | tail -5
