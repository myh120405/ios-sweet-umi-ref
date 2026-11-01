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
add_line iokit/conf/files.arm64 $'iokit/Kernel/arm/UmiFtsTouch.cpp\toptional iokitcpp'
add_line iokit/conf/files.arm64 $'iokit/Kernel/arm/UmiKeys.cpp\toptional iokitcpp'
add_line iokit/conf/files.arm64 $'iokit/Kernel/arm/UmiSweetBridge.cpp\toptional iokitcpp'
# bsd/dev/sweet_gpu.c brings the GPU up and is called from sweet_ufs.c; the
# patch stages the file but does not list it.
add_line bsd/conf/files $'bsd/dev/sweet_gpu.c\t\tstandard'

# The root-volume guard needs a generated private UmiRootVolume.h. The public
# .in template has a zero identity: it compiles and gates every write, but a
# real 16 GiB HFSX root will not match it. See reports/ref-kernel-build.md.
cp "$TOP/vendor/UmiRootVolume.h" bsd/dev/UmiRootVolume.h
echo "ref-integrate: iokit units + sweet_gpu.c listed; bsd/dev/UmiRootVolume.h written (zero identity)"

# Fail loudly if the makefile lists did not take (a silently unbuilt touch or
# GPU driver would look like a runtime bug).
grep -q 'UmiFtsTouch.cpp' iokit/conf/files.arm64 || { echo "::error::UmiFtsTouch.cpp not listed"; exit 1; }
grep -q 'SweetGPU.cpp' iokit/conf/files.arm64 || { echo "::error::SweetGPU.cpp not listed"; exit 1; }
grep -q 'sweet_gpu.c' bsd/conf/files || { echo "::error::sweet_gpu.c not listed"; exit 1; }
