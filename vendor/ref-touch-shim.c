/*
 * Build shim for the reference kernel when the native FTS touch unit is not
 * compiled in.
 *
 * bsd/dev/sweet_ufs.c (the reference one) calls umi_sweet_touch_start() after
 * the root partition is known.  That symbol is defined in
 * iokit/Kernel/arm/UmiSweetBridge.cpp, which in turn calls native_touch_probe()
 * and umi_touch_next() from iokit/Kernel/arm/UmiFtsTouch.cpp.  The published v6
 * source ships UmiFtsTouch.cpp but not the 17 private headers it includes
 * (UmiTouchPlatform.h, UmiBoardBoost.h, UmiFtsPowerSequence.h, UmiFtsGpiCore.h,
 * UmiFts*.inc, ...), so neither unit can be built from the publication.
 *
 * This shim keeps the reference kernel linkable without those units.  It does
 * not touch hardware and it does not replace the legacy bsd/dev/sweet_touch.c
 * path (which the reference itself calls only under #if 0).  Remove it when the
 * private headers are available.
 */
#if defined(ARM64_BOARD_CONFIG_SWEET)
#include <sys/systm.h>

void
umi_sweet_touch_start(void)
{
	printf("UMI input: native FTS touch not built (published headers incomplete)\n");
}
#endif
