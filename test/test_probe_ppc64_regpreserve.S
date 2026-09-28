/*
            Copyright Oliver Kowalke 2009.
   Distributed under the Boost Software License, Version 1.0.
      (See accompanying file LICENSE_1_0.txt or copy at
          http://www.boost.org/LICENSE_1_0.txt)

   ppc64le SysV ELF register-preservation probe for jump_fcontext.

   These functions are non-leaf (they call jump_fcontext via bl) so they
   MUST set up a proper stack frame and save LR — otherwise jump_fcontext
   captures the wrong return address as the resume PC and the test hangs.

   Critically, the frame saves only what the ABI requires (LR, back-chain).
   It deliberately does NOT save f14 or v20, so those registers cross the
   jump_fcontext call with zero compiler interference.  jump_fcontext is the
   only thing responsible for preserving them across the switch.

   Frame layout (both probes, 64 bytes):
     r1+0   : back-chain (old r1)
     r1+16  : saved LR  (ABI: LR save word is at caller_sp+16)
     r1+32  : padding to 64-byte frame (must be 16-byte aligned)
   Total: 64 bytes (minimum ABI frame for a function with a bl).
*/

#if _CALL_ELF == 2

.file "test_probe_ppc64_regpreserve.S"
.text
.align 2

/* ── probe_fpr_jump ──────────────────────────────────────────────────────── */
/* double probe_fpr_jump(fcontext_t fctx)
   r3 = fctx passed straight through as first arg to jump_fcontext.
   Loads pi (0x400921FB54442D18) into f14, calls jump_fcontext(fctx, 0),
   then returns f14 in f1.  The frame saves LR but NOT f14.
*/
.globl probe_fpr_jump
.type  probe_fpr_jump, @function
probe_fpr_jump:
    .localentry probe_fpr_jump, 0

    /* Standard non-leaf prologue: save LR, allocate frame. */
    mflr  %r0
    std   %r0, 16(%r1)          /* save LR at caller_sp+16 */
    stdu  %r1, -64(%r1)         /* allocate 64-byte frame, store back-chain */

    /* Build pi bit pattern (0x400921FB54442D18) in r5:r6, store to frame,
       load into f14 via lfd.  We use the frame scratch area (r1+32). */
    lis   %r5, 0x4009
    ori   %r5, %r5, 0x21FB
    sldi  %r5, %r5, 32
    lis   %r6, 0x5444
    ori   %r6, %r6, 0x2D18
    or    %r5, %r5, %r6
    std   %r5, 32(%r1)
    lfd   %f14, 32(%r1)         /* f14 = pi — NOT saved in prologue */

    /* Call jump_fcontext(fctx, NULL):  r3=fctx (already set), r4=0. */
    li    %r4, 0
    bl    jump_fcontext
    nop

    /* Epilogue: restore LR, deallocate frame, return f14 in f1. */
    addi  %r1, %r1, 64
    ld    %r0, 16(%r1)
    mtlr  %r0
    fmr   %f1, %f14
    blr

    .size probe_fpr_jump, .-probe_fpr_jump


/* ── probe_vmx_jump ──────────────────────────────────────────────────────── */
/* uint64_t probe_vmx_jump(fcontext_t fctx)
   Loads 0xDEADBEEFCAFEBABE into v20 (VS52), calls jump_fcontext(fctx, 0),
   returns low 64 bits of v20 in r3.  Frame saves LR but NOT v20.
*/
.globl probe_vmx_jump
.type  probe_vmx_jump, @function
probe_vmx_jump:
    .localentry probe_vmx_jump, 0

    /* Standard non-leaf prologue. */
    mflr  %r0
    std   %r0, 16(%r1)
    stdu  %r1, -64(%r1)

    /* Build VMX sentinel 0xDEADBEEFCAFEBABE in r5, load into v20 via mtvsrd.
       VS52 = v20.  mtvsrd sets the *upper* 64 bits of the VSX register
       (i.e. the scalar portion); mfvsrd reads the same upper 64 bits. */
    lis   %r5, 0xDEAD
    ori   %r5, %r5, 0xBEEF
    sldi  %r5, %r5, 32
    lis   %r6, 0xCAFE
    ori   %r6, %r6, 0xBABE
    or    %r5, %r5, %r6
    mtvsrd 52, %r5              /* v20 = sentinel — NOT saved in prologue */

    /* Call jump_fcontext(fctx, NULL). */
    li    %r4, 0
    bl    jump_fcontext
    nop

    /* Epilogue: restore LR, deallocate frame, return v20 low bits in r3. */
    addi  %r1, %r1, 64
    ld    %r0, 16(%r1)
    mtlr  %r0
    mfvsrd %r3, 52
    blr

    .size probe_vmx_jump, .-probe_vmx_jump

#endif /* _CALL_ELF == 2 */

/* Mark that we don't need executable stack.  */
.section .note.GNU-stack,"",%progbits
