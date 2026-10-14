# AnyKernel3 template for Droidspaces sm7325 kernels.
# Materialized per device by droidspaces/package.sh (@DEVICE@/@REL@).
#
# Lint note: this file must keep AnyKernel3's canonical structure
# (properties() multiline block, UPPER_CASE vars consumed by tools/ak3-core.sh
# at flash time), so SC2289/SC2034 are accepted deviations, disabled below.
# shellcheck disable=SC2289,SC2034
#
# Two-partition profile (hdr v3, A-only, dynamic super):
#   1. boot        <- our Image (stock ramdisk + stock dtb kept: our tree
#                     changes no driver and no DT binding)
#   2. vendor_boot <- our 54 rebuilt modules injected into the vendor ramdisk
#                     (vendor_ramdisk/ dir in this zip; ak3-core auto-stages it
#                     into vendor_boot-files). Stock ramdisk + stock dtbo kept.
# Recovery is never touched (it carries its own kernel + modules).

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
# NOTE: do.modules=1 is conventional for kernel zips; on this layout the
# modules travel via vendor_ramdisk/ (vendor_boot), not a live-partition
# modules/ dir, so there is no live-fs install step.


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

# boot install: new Image, stock ramdisk+dtb preserved
dump_boot;
write_boot;
## end boot install


## vendor_boot files attributes
vendor_boot_attributes() {
set_perm_recursive 0 0 755 644 "$RAMDISK"/*;
set_perm_recursive 0 0 750 750 "$RAMDISK"/init* "$RAMDISK"/sbin;
} # end attributes

# vendor_boot shell variables (A-only device: no slot suffix)
BLOCK=vendor_boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# reset for vendor_boot patching
reset_ak;

# vendor_boot install: inject vendor_ramdisk/ (our modules) into a repack of
# the stock vendor_boot, then flash. Verify on first flash: Wi-Fi, Bluetooth,
# camera + `lsmod` count vs MODULES.txt in the release notes.
dump_boot;
write_boot;
## end vendor_boot install
