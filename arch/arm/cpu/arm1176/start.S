/* SPDX-License-Identifier: GPL-2.0+ */
/*
 *  armboot - Startup Code for ARM1176 CPU-core
 *
 * Copyright (c) 2007	Samsung Electronics
 *
 * Copyright (C) 2008
 * Guennadi Liakhovetki, DENX Software Engineering, <lg@denx.de>
 *
 * 2007-09-21 - Restructured codes by jsgood (jsgood.yang@samsung.com)
 * 2007-09-21 - Added MoviNAND and OneNAND boot codes by
 * jsgood (jsgood.yang@samsung.com)
 * Base codes by scsuh (sc.suh)
 */

#include <asm-offsets.h>
#include <config.h>
#include <linux/linkage.h>

#ifndef CONFIG_SYS_PHY_UBOOT_BASE
#define CONFIG_SYS_PHY_UBOOT_BASE	CONFIG_SYS_UBOOT_BASE
#endif

/*
 *************************************************************************
 *
 * Startup Code (reset vector)
 *
 * do important init only if we don't start from memory!
 * setup Memory and board specific bits prior to relocation.
 * relocate armboot to ram
 * setup stack
 *
 *************************************************************************
 */

	.globl reset

reset:
	/* Allow the board to save important registers */
	b	save_boot_params
.globl	save_boot_params_ret
save_boot_params_ret:
#ifdef CONFIG_POSITION_INDEPENDENT
    /*
     * Fix .rela.dyn relocations. This allows U-Boot to loaded to and
     * executed at a different address than it was linked at.
     */
pie_fixup:
    adr r0, reset   /* r0 <- Runtime value of reset label */
    ldr r1, =reset  /* r1 <- Linked value of reset label */
    subs    r4, r0, r1  /* r4 <- Runtime-vs-link offset */
    beq pie_fixup_done

    adr r0, pie_fixup
    ldr r1, _rel_dyn_start_ofs
    add r2, r0, r1  /* r2 <- Runtime &__rel_dyn_start */
    ldr r1, _rel_dyn_end_ofs
    add r3, r0, r1  /* r3 <- Runtime &__rel_dyn_end */

pie_fix_loop:
    ldr r0, [r2]    /* r0 <- Link location */
    ldr r1, [r2, #4]    /* r1 <- fixup */
    cmp r1, #23     /* relative fixup? */
    bne pie_skip_reloc

    /* relative fix: increase location by offset */
    add r0, r4
    ldr r1, [r0]
    add r1, r4
    str r1, [r0]
    str r0, [r2]
    add r2, #8
pie_skip_reloc:
    cmp r2, r3
    blo pie_fix_loop
pie_fixup_done:
#endif

	/*
	 * set the cpu to SVC32 mode
	 */
	mrs	r0, cpsr
	bic	r0, r0, #0x3f
	orr	r0, r0, #0xd3
	msr	cpsr, r0

/*
 *************************************************************************
 *
 * CPU_init_critical registers
 *
 * setup important registers
 * setup memory timing
 *
 *************************************************************************
 */
	/*
	 * we do sys-critical inits only at reboot,
	 * not when booting from ram!
	 */
cpu_init_crit:
	/*
	 * When booting from NAND - it has definitely been a reset, so, no need
	 * to flush caches and disable the MMU
	 */
#ifndef CONFIG_SPL_BUILD
	/*
	 * flush v4 I/D caches
	 */
	mov	r0, #0
	mcr	p15, 0, r0, c7, c7, 0	/* flush v3/v4 cache */
	mcr	p15, 0, r0, c8, c7, 0	/* flush v4 TLB */

	/*
	 * disable MMU stuff and caches
	 */
	mrc	p15, 0, r0, c1, c0, 0
	bic	r0, r0, #0x00002300	@ clear bits 13, 9:8 (--V- --RS)
	bic	r0, r0, #0x00000087	@ clear bits 7, 2:0 (B--- -CAM)
	orr	r0, r0, #0x00000002	@ set bit 1 (A) Align
	orr	r0, r0, #0x00001000	@ set bit 12 (I) I-Cache

	/* Prepare to disable the MMU */
	adr	r2, mmu_disable_phys
	sub	r2, r2, #(CONFIG_SYS_PHY_UBOOT_BASE - CONFIG_TEXT_BASE)
	b	mmu_disable

	.align 5
	/* Run in a single cache-line */
mmu_disable:
	mcr	p15, 0, r0, c1, c0, 0
	nop
	nop
	mov	pc, r2
mmu_disable_phys:

#endif

	/*
	 * Go setup Memory and board specific bits prior to relocation.
	 */
	bl	lowlevel_init		/* go setup pll,mux,memory */

	bl	_main

/*------------------------------------------------------------------------------*/

	.globl	c_runtime_cpu_setup
c_runtime_cpu_setup:

	mov	pc, lr

WEAK(save_boot_params)
	b	save_boot_params_ret	/* back to my caller */
ENDPROC(save_boot_params)

#if CONFIG_POSITION_INDEPENDENT
_rel_dyn_start_ofs:
    .word   __rel_dyn_start - pie_fixup
_rel_dyn_end_ofs:
    .word   __rel_dyn_end - pie_fixup
#endif

