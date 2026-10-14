# AnyKernel3 template for Droidspaces sm7325 kernels.
# Materialized per device by droidspaces/package.sh (@DEVICE@/@REL@).
#
# Lint note: this file must keep AnyKernel3's canonical structure
# (properties() multiline block, UPPER_CASE vars consumed by tools/ak3-core.sh
# at flash time), so SC2289/SC2034 are accepted deviations, disabled below.
# shellcheck disable=SC2289,SC2034
#
# Boot-only profile, verified against the official Lineage nightly:
#   - boot        <- our Image (stock ramdisk + stock dtb kept: our tree
#                     changes no driver and no DT binding)
#   - /vendor     <- our 87 rebuilt modules into vendor/lib/modules
#                     (do.modules=1 installs the zip's modules/ tree live).
# Layout evidence (forensic, Oct 2026 nightly): official vendor_boot ramdisk
# contains ONLY fstab (no modules, no modules.load); all 87 modules plus
# modules.load/dep/alias/softdep live in vendor.img /lib/modules. So modules
# must go to live /vendor - a vendor_boot injection would sit unloaded while
# stock (wrong-CRC) modules stay live. Recovery is never touched.

### AnyKernel setup
# begin properties
properties() { '
kernel.string=Droidspaces sm7325 @DEVICE@ @REL@ by droidspaces-sm7325 CI
do.devicecheck=1
do.modules=1
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=@DEVICE@
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties
# NOTE: do.modules=1 installs this zip's modules/vendor/... tree onto the
# live vendor partition (that's what the flag is for).


### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 "$RAMDISK"/*;
set_perm_recursive 0 0 750 750 "$RAMDISK"/init* "$RAMDISK"/sbin;
} # end attributes

# boot shell variables
BLOCK=boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install: new Image, stock ramdisk+dtb preserved.
# Then AnyKernel's modules step installs modules/vendor/... to /vendor.
# Verify on first flash: Wi-Fi, Bluetooth, camera, `lsmod` count vs
# MODULES.txt in the release notes, and `dmesg | grep -i vers` clean.
dump_boot;
write_boot;
## end boot install
