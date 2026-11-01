#!/bin/bash
# Put the reference implementation (leafall903/ios-sweet-umi v6) on a pristine
# xnu-8796.141.3 tree, on Linux.
#
#   1. fetch exactly one tag of apple-oss-distributions/xnu (shallow), check its SHA;
#   2. apply vendor/umi-v6.patch - the consolidated 5.7 MB tree patch.  It is
#      self-contained: config/MASTER.arm64.sweet, bsd/sweet_hfs, bsd/pthread/
#      sweet_libpthread and libkern/crypto/sweet_bearssl are all new files in it,
#      so no stage scripts and none of the old xnu/patches series are used;
#   3. linux/ref-integrate.sh - the four translation units the reference built
#      outside the makefile list (SweetGPU, UmiFtsTouch, UmiKeys, UmiSweetBridge)
#      and bsd/dev/sweet_gpu.c, plus the generated UmiRootVolume.h;
#   4. linux/fixes/*.patch - stock-clang fixes, applied after and never skipped.
#
# A patch that does not apply stops the run with git apply's message, the files
# it touches, and GNU patch's per-hunk dry run. Nothing is skipped.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/env.sh"
REPO=${XNU_REPO:-https://github.com/apple-oss-distributions/xnu.git}
: "${XNU_TAG:?XNU_TAG is not set}"
: "${XNU_TAG_SHA:?XNU_TAG_SHA is not set}"
: "${XNU_SRC:?XNU_SRC is not set}"

log() { echo "apply-ref: $*"; }
die() { echo "::error::$*" >&2; exit 1; }

PATCH=$TOP/vendor/umi-v6.patch
[ -f "$PATCH" ] || die "no vendor patch at $PATCH"

rm -rf "$XNU_SRC"
mkdir -p "$(dirname "$XNU_SRC")"
log "fetching $REPO $XNU_TAG"
git clone -q --depth 1 --branch "$XNU_TAG" --single-branch "$REPO" "$XNU_SRC"
got=$(git -C "$XNU_SRC" rev-parse HEAD)
[ "$got" = "$XNU_TAG_SHA" ] || die "$XNU_TAG is $got, expected $XNU_TAG_SHA"
log "xnu tree at $got"

nfiles=$(grep -c '^diff --git' "$PATCH")
log "vendor patch: $(wc -c <"$PATCH") bytes, sha256 $(sha256sum "$PATCH" | cut -d' ' -f1), $nfiles files"

if ! git -C "$XNU_SRC" apply --check --whitespace=nowarn "$PATCH" 2>"$XNU_SRC/.apply.err"; then
	echo "::error::vendor/umi-v6.patch does not apply to $XNU_TAG ($got)"
	echo "----- git apply --check said:"
	sed 's/^/  /' "$XNU_SRC/.apply.err"
	echo "----- files in the patch (first 40):"
	grep -E '^diff --git' "$PATCH" | head -40 | sed 's/^/  /'
	echo "----- git apply --check -v (per-file verdicts):"
	(cd "$XNU_SRC" && git apply --check -v --whitespace=nowarn "$PATCH" 2>&1 || true) | tail -60 | sed 's/^/  /'
	echo "----- GNU patch -p1 --dry-run -f (per-hunk detail):"
	(cd "$XNU_SRC" && patch -p1 --dry-run -f --batch <"$PATCH" 2>&1 || true) | grep -E 'Hunk|FAILED|Reversed|saving|patching file' | head -80 | sed 's/^/  /'
	exit 1
fi
git -C "$XNU_SRC" apply --whitespace=nowarn "$PATCH"
log "vendor patch applied"

# Every file the patch announces must exist in the tree after applying it.
missing=0
while IFS= read -r p; do
	[ -e "$XNU_SRC/$p" ] || { echo "::error::missing after apply: $p"; missing=$((missing + 1)); }
done < <(grep '^diff --git' "$PATCH" | sed 's|^diff --git a/||;s| b/.*||')
[ "$missing" -eq 0 ] || die "$missing file(s) announced by the patch are missing"
log "all $nfiles announced files are present"

bash "$HERE/ref-integrate.sh"

for f in "$HERE"/fixes/*.patch; do
	[ -f "$f" ] || continue
	if ! git -C "$XNU_SRC" apply -v --whitespace=nowarn "$f"; then
		die "overlay fix $(basename "$f") does not apply"
	fi
	log "overlay fix $(basename "$f")"
done

# Linux build-system adjustment, the same kind darwin-xnu-build makes on macOS.
sed -i \
	-e 's|XCRUN = /usr/bin/xcrun|XCRUN = xcrun|' \
	-e 's|HOST_CODESIGN\([[:space:]]*\):=[[:space:]]*/usr/bin/codesign|HOST_CODESIGN\1:= codesign|' \
	-e 's|PLUTIL = /usr/bin/plutil|PLUTIL = plutil|' \
	"$XNU_SRC/makedefs/MakeInc.cmd"
grep -q 'XCRUN = xcrun' "$XNU_SRC/makedefs/MakeInc.cmd" || die "could not point XCRUN at the xcrun on PATH"
grep -q 'HOST_CODESIGN[[:space:]]*:=[[:space:]]*codesign' "$XNU_SRC/makedefs/MakeInc.cmd" || die "could not point HOST_CODESIGN at the codesign stub"
grep -q 'PLUTIL = plutil' "$XNU_SRC/makedefs/MakeInc.cmd" || die "could not point PLUTIL at the plutil stub"
log "makedefs/MakeInc.cmd: XCRUN, HOST_CODESIGN and PLUTIL now resolve from PATH"

sed -i 's|^#!/bin/csh -f$|#!/usr/bin/env -S csh -f|' "$XNU_SRC/SETUP/config/doconf"
grep -q '^#!/usr/bin/env -S csh -f$' "$XNU_SRC/SETUP/config/doconf" || die "could not point SETUP/config/doconf at the csh on PATH"
log "SETUP/config/doconf: runs under env -S csh -f"
