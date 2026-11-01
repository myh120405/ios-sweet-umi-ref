/*
 * Build shim for the reference kernel.
 *
 * Two jobs, both weak so that a real definition always wins:
 *
 * 1. umi_sweet_touch_start(): bsd/dev/sweet_ufs.c (the reference one) calls it
 *    after the root partition is known.  The symbol lives in
 *    iokit/Kernel/arm/UmiSweetBridge.cpp, which calls native_touch_probe() and
 *    umi_touch_next() from iokit/Kernel/arm/UmiFtsTouch.cpp.  The published v6
 *    snapshot ships UmiFtsTouch.cpp but not the 17 private headers it includes
 *    (UmiTouchPlatform.h, UmiBoardBoost.h, UmiFtsPowerSequence.h,
 *    UmiFtsGpiCore.h, UmiFts*.inc, ...), so neither unit can be built.
 *
 * 2. The sweetlog API (sweet_log_append/copy/position/kick): defined by the
 *    reference's sweet_ufs.c and called from serial_console.c, sweet_usb.c and
 *    kern_exec.c.  The "ourroot" kernel replaces sweet_ufs.c with our proven
 *    UFS driver, which does not carry the persistent-log code, so these weak
 *    no-ops keep that kernel linkable.  With the reference driver they are
 *    overridden and the real ring log is used.
 *
 * No hardware access, no behaviour change to display or input.
 */
#if defined(ARM64_BOARD_CONFIG_SWEET)
#include <sys/systm.h>

__attribute__((weak)) void
umi_sweet_touch_start(void)
{
	printf("UMI input: native FTS touch not built (published headers incomplete)\n");
}

__attribute__((weak)) void
sweet_log_append(const char *c, int size)
{
	(void)c;
	(void)size;
}

__attribute__((weak)) uint32_t
sweet_log_copy(uint64_t *pos, char *out, uint32_t max)
{
	(void)pos;
	(void)out;
	(void)max;
	return 0;
}

__attribute__((weak)) uint64_t
sweet_log_position(void)
{
	return 0;
}

__attribute__((weak)) void
sweet_log_kick(void)
{
}
#endif
