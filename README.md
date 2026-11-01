# ios-sweet-umi-ref

Builds the **reference implementation** of the umi (Xiaomi Mi 10 / SM8250) XNU
kernel on an Ubuntu runner, from
[`leafall903/ios-sweet-umi`](https://github.com/leafall903/ios-sweet-umi)
tag `umi-ios16.5-v6`, not from our own port (`myh982516/ios-sweet-umi`).

| what | value |
|---|---|
| XNU | `xnu-8796.141.3` @ `1b191cb58250d0705d8a51287127505aa4bc0789` |
| patch | `vendor/umi-v6.patch` (5,906,661 B, consolidated tree patch; self-contained: HFS, libpthread, BearSSL, config, all 350 files) |
| extra integration | `linux/ref-integrate.sh`: SweetGPU, UmiFtsTouch, UmiKeys, UmiSweetBridge, `sweet_gpu.c` + generated `UmiRootVolume.h` |
| SDK | `MacOSX13.3.sdk`, `SDKROOT=macosx` |
| config | `ARM64 / SWEET / DEVELOPMENT` |
| toolchain | theos cctools (`ld64`) + stock clang via `linux/bin/xnu-clang` |

`linux/` is copied from `myh120405/ios-sweet-linux` (the dependency bootstrap,
SDK overlay, DriverKit iig stubs and `xnu-clang` wrapper are unchanged); only
the patch stage is replaced by `linux/apply-ref.sh`.

Two kernels per run:

- `kernel.development.sweet` — the reference root transport, verbatim. It only
  exposes the UFS root after their loader passes a `dma-pool` ADT property
  (`ufs-lowdma=1`) and the volume matches a generated 16 GiB HFSX identity
  (`UmiRootVolume.h`); the publication does not ship that loader.
- `kernel.development.sweet.ourroot` — identical except `bsd/dev/sweet_ufs.c`
  is our proven driver (`/sweet-ufs` ADT node, `rd=ufsroot0`), so it can root
  our existing image.

See `reports/ref-kernel-build.md` in the workspace for the boot-argument
findings and risks.
