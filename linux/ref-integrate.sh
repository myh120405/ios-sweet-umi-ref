#!/bin/bash
# Integration steps the reference did outside its makefile list, plus the one
# generated header the publication deliberately omits.
#
# docs/reproduction.md: "Some extra units (SweetGPU, sweet_gpu, UmiKeys,
# UmiSweetBridge, UmiFtsTouch) were integrated outside the original make-file
# list. Merely running make against the consolidated patch does not perform
# that integration."  This script performs exactly that, and nothing else.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/env.sh"
cd "$XNU_SRC"

add_line() {
	local file=$1 line=$2
	grep -qxF "$line" "$file" || printf '%s\n' "$line" >>"$file"
}

# iokit translation units: SweetPlatformExpert/SweetCPU/SweetSurface/
# SweetFramebuffer already come listed in the patch's iokit/conf/files.arm64.
add_line iokit/conf/files.arm64 $'iokit/Kernel/arm/SweetGPU.cpp\toptional iokitcpp'
# NOT built: UmiFtsTouch.cpp, UmiSweetBridge.cpp, UmiKeys.cpp.
# The published snapshot has UmiFtsTouch.cpp but not the 17 private headers it
# #includes (UmiTouchPlatform.h, UmiBoardBoost.h, UmiFtsPowerSequence.h,
# UmiFtsGpiCore.h, UmiFts*.inc, ...).  UmiSweetBridge calls native_touch_probe()
# and umi_touch_next(), both defined only in UmiFtsTouch.cpp; UmiKeys calls
# umi_input_is_umi(), also defined there.  So none of the three can link from the
# publication.  bsd/dev/sweet_touch.c (the legacy path, which the reference
# itself calls only under #if 0) is listed by the patch but not enabled here.
# vendor/ref-touch-shim.c supplies the one symbol sweet_ufs.c calls.
add_line bsd/conf/files $'bsd/dev/sweet_gpu.c\t\tstandard'
add_line bsd/conf/files $'bsd/dev/sweet_ref_shim.c\t\tstandard'
cp "$TOP/vendor/ref-touch-shim.c" bsd/dev/sweet_ref_shim.c

# The root-volume guard needs a generated private UmiRootVolume.h. The public
# .in template has a zero identity: it compiles and gates every write, but a
# real 16 GiB HFSX root will not match it. See reports/ref-kernel-build.md.
cp "$TOP/vendor/UmiRootVolume.h" bsd/dev/UmiRootVolume.h
echo "ref-integrate: iokit units + sweet_gpu.c listed; bsd/dev/UmiRootVolume.h written (zero identity)"

# Fail loudly if the makefile lists did not take (a silently unbuilt touch or
# GPU driver would look like a runtime bug).
grep -q 'SweetGPU.cpp' iokit/conf/files.arm64 || { echo "::error::SweetGPU.cpp not listed"; exit 1; }
grep -q 'sweet_gpu.c' bsd/conf/files || { echo "::error::sweet_gpu.c not listed"; exit 1; }
grep -q 'sweet_ref_shim.c' bsd/conf/files || { echo "::error::sweet_ref_shim.c not listed"; exit 1; }
