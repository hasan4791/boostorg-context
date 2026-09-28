/*
            Copyright Oliver Kowalke 2009.
   Distributed under the Boost Software License, Version 1.0.
      (See accompanying file LICENSE_1_0.txt or copy at
          http://www.boost.org/LICENSE_1_0.txt)

   ppc64le SysV ELF register-preservation probe for jump_fcontext.

   Exported C functions:
     double  probe_fpr_jump(fcontext_t fctx)
       Load a known sentinel into f14, call jump_fcontext(fctx, 0),
       return whatever is in f14 after the call.
       If jump_fcontext saves/restores f14 correctly this equals the sentinel.
       If not, it equals whatever the other context left in f14.

     uint64_t probe_vmx_jump(fcontext_t fctx)
       Same for v20 (VS52): load sentinel into v20 via mtvsrd, call
       jump_fcontext, return low 64 bits of v20 via mfvsrd.

   The sentinels are defined in the C++ test and passed via globals so
   the asm file needs no relocation.  We just use hard-coded immediates:
     FPR sentinel: 0x400921FB54442D18  (IEEE 754 double for pi)
     VMX sentinel: 0xDEADBEEFCAFEBABE

   These are stand-alone leaf functions: no back-chain, no local frame,
   no saved registers — the compiler cannot insert any prologue/epilogue.
   Any save/restore of f14 or v20 is done *only* by jump_fcontext itself.
*/

#if _CALL_ELF == 2

.file "test_probe_ppc64_regpreserve.S"
.text
.align 2

/* ── probe_fpr_jump ──────────────────────────────────────────────────────── */
/* double probe_fpr_jump(fcontext_t fctx)
   r3 = fctx (first arg, also used as second arg to jump_fcontext with value=0)
   Returns double in f1.
*/
.globl probe_fpr_jump
.type  probe_fpr_jump, @function
probe_fpr_jump:
    .localentry probe_fpr_jump, 0

    /* Load pi sentinel into f14.
       We need the 64-bit IEEE 754 bit pattern 0x400921FB54442D18 into f14.
       Strategy: store to a stack temp, load with lfd.
       Use the red zone (128 bytes below r1, safe to use in leaf functions). */
    lis   %r5, 0x4009
    ori   %r5, %r5, 0x21FB
    sldi  %r5, %r5, 32
    lis   %r6, 0x5444
    ori   %r6, %r6, 0x2D18
    or    %r5, %r5, %r6
    std   %r5, -8(%r1)
    lfd   %f14, -8(%r1)          /* f14 = pi sentinel */

    /* Call jump_fcontext(fctx, NULL).
       r3 already holds fctx; r4 = 0 (data pointer). */
    li    %r4, 0
    bl    jump_fcontext
    nop

    /* Return f14 in f1 — whatever jump_fcontext left in it. */
    fmr   %f1, %f14
    blr

    .size probe_fpr_jump, .-probe_fpr_jump


/* ── probe_vmx_jump ──────────────────────────────────────────────────────── */
/* uint64_t probe_vmx_jump(fcontext_t fctx)
   Returns low 64 bits of v20 after the jump, in r3.
*/
.globl probe_vmx_jump
.type  probe_vmx_jump, @function
probe_vmx_jump:
    .localentry probe_vmx_jump, 0

    /* Load VMX sentinel 0xDEADBEEFCAFEBABE into v20 (VS52) via mtvsrd. */
    lis   %r5, 0xDEAD
    ori   %r5, %r5, 0xBEEF
    sldi  %r5, %r5, 32
    lis   %r6, 0xCAFE
    ori   %r6, %r6, 0xBABE
    or    %r5, %r5, %r6
    mtvsrd 52, %r5               /* VS52 = v20; low 64 bits = sentinel */

    /* Call jump_fcontext(fctx, NULL). */
    li    %r4, 0
    bl    jump_fcontext
    nop

    /* Return low 64 bits of v20 in r3. */
    mfvsrd %r3, 52
    blr

    .size probe_vmx_jump, .-probe_vmx_jump

#endif /* _CALL_ELF == 2 */

/* Mark that we don't need executable stack.  */
.section .note.GNU-stack,"",%progbits
