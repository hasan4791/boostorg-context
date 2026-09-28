/*
            Copyright Oliver Kowalke 2009.
   Distributed under the Boost Software License, Version 1.0.
      (See accompanying file LICENSE_1_0.txt or copy at
          http://www.boost.org/LICENSE_1_0.txt)
*/

/*******************************************************
 *                                                     *
 *  -------------------------------------------------  *
 *  |  0  |  1  |  2  |  3  |  4  |  5  |  6  |  7  |  *
 *  -------------------------------------------------  *
 *  |  0  |  4  |  8  |  12 |  16 |  20 |  24 |  28 |  *
 *  -------------------------------------------------  *
 *  |    TOC    |    R14    |    R15    |    R16    |  *
 *  -------------------------------------------------  *
 *  -------------------------------------------------  *
 *  |  8  |  9  |  10 |  11 |  12 |  13 |  14 |  15 |  *
 *  -------------------------------------------------  *
 *  |  32 |  36 |  40 |  44 |  48 |  52 |  56 |  60 |  *
 *  -------------------------------------------------  *
 *  |    R17    |    R18    |     R19   |    R20    |  *
 *  -------------------------------------------------  *
 *  -------------------------------------------------  *
 *  |  16 |  17 |  18 |  19 |  20 |  21 |  22 |  23 |  *
 *  -------------------------------------------------  *
 *  |  64 |  68 |  72 |  76 |  80 |  84 |  88 |  92 |  *
 *  -------------------------------------------------  *
 *  |    R21    |    R22    |    R23    |    R24    |  *
 *  -------------------------------------------------  *
 *  -------------------------------------------------  *
 *  |  24 |  25 |  26 |  27 |  28 |  29 |  30 |  31 |  *
 *  -------------------------------------------------  *
 *  |  96 | 100 | 104 | 108 | 112 | 116 | 120 | 124 |  *
 *  -------------------------------------------------  *
 *  |    R25    |    R26    |    R27    |    R28    |  *
 *  -------------------------------------------------  *
 *  -------------------------------------------------  *
 *  |  32 |  33 |  34 |  35 |  36 |  37 |  38 |  39 |  *
 *  -------------------------------------------------  *
 *  | 128 | 132 | 136 | 140 | 144 | 148 | 152 | 156 |  *
 *  -------------------------------------------------  *
 *  |    R29    |    R30    |    R31    |   hidden  |  *
 *  -------------------------------------------------  *
 *  -------------------------------------------------  *
 *  |  40 |  41 |  42 |  43 |  44 |  45 |  46 |  47 |  *
 *  -------------------------------------------------  *
 *  | 160 | 164 | 168 | 172 | 176 | 180 |           |  *
 *  -------------------------------------------------  *
 *  |     CR    |     LR    |     PC    |  (pad/gap) |  *
 *  -------------------------------------------------  *
 *  -------------------------------------------------  *
 *  |  48 |  49 |  50 |  51 |  52 |  53 |  54 |  55 |  *
 *  -------------------------------------------------  *
 *  | 192 | 196 | 200 | 204 | 208 | 212 | 216 | 220 |  *
 *  -------------------------------------------------  *
 *  |  cr saved |  lr saved |  compiler |   linker  |  *
 *  -------------------------------------------------  *
 *  -------------------------------------------------  *
 *  |  56 |  57 |  58 |  59 |  60 |  61 |  62 |  63 |  *
 *  -------------------------------------------------  *
 *  | 224 | 228 | 232 | 236 | 240 | 244 | 248 | 252 |  *
 *  -------------------------------------------------  *
 *  | TOC saved |    FCTX   |    DATA   |           |  *
 *  -------------------------------------------------  *
 *                                                     *
 *  NOTE: offsets 184-252 above describe the standard   *
 *  ABI linkage area present in the original frame.     *
 *  In this extended frame those slots are now used     *
 *  for VMX (v20-v31) and FPR (f14-f31) saves instead. *
 *  The VMX/FPR layout starts at offset 184 below.      *
 *                                                     *
 *  8-byte pad (184–191) aligns VMX area to 16 bytes.  *
 *                                                     *
 *  -------------------------------------------------  *
 *  |       VS63 (v31)      |       VS62 (v30)      |  *
 *  -------------------------------------------------  *
 *  |      192–207          |      208–223          |  *
 *  -------------------------------------------------  *
 *  |       VS61 (v29)      |       VS60 (v28)      |  *
 *  -------------------------------------------------  *
 *  |      224–239          |      240–255          |  *
 *  -------------------------------------------------  *
 *  |       VS59 (v27)      |       VS58 (v26)      |  *
 *  -------------------------------------------------  *
 *  |      256–271          |      272–287          |  *
 *  -------------------------------------------------  *
 *  |       VS57 (v25)      |       VS56 (v24)      |  *
 *  -------------------------------------------------  *
 *  |      288–303          |      304–319          |  *
 *  -------------------------------------------------  *
 *  |       VS55 (v23)      |       VS54 (v22)      |  *
 *  -------------------------------------------------  *
 *  |      320–335          |      336–351          |  *
 *  -------------------------------------------------  *
 *  |       VS53 (v21)      |       VS52 (v20)      |  *
 *  -------------------------------------------------  *
 *  |      352–367          |      368–383          |  *
 *  -------------------------------------------------  *
 *                                                     *
 *  -------------------------------------------------  *
 *  |       F14         |       F15         |          *
 *  -------------------------------------------------  *
 *  |      384–391      |      392–399      |          *
 *  -------------------------------------------------  *
 *  |       F16         |       F17         |          *
 *  -------------------------------------------------  *
 *  |      400–407      |      408–415      |          *
 *  -------------------------------------------------  *
 *  |       F18         |       F19         |          *
 *  -------------------------------------------------  *
 *  |      416–423      |      424–431      |          *
 *  -------------------------------------------------  *
 *  |       F20         |       F21         |          *
 *  -------------------------------------------------  *
 *  |      432–439      |      440–447      |          *
 *  -------------------------------------------------  *
 *  |       F22         |       F23         |          *
 *  -------------------------------------------------  *
 *  |      448–455      |      456–463      |          *
 *  -------------------------------------------------  *
 *  |       F24         |       F25         |          *
 *  -------------------------------------------------  *
 *  |      464–471      |      472–479      |          *
 *  -------------------------------------------------  *
 *  |       F26         |       F27         |          *
 *  -------------------------------------------------  *
 *  |      480–487      |      488–495      |          *
 *  -------------------------------------------------  *
 *  |       F28         |       F29         |          *
 *  -------------------------------------------------  *
 *  |      496–503      |      504–511      |          *
 *  -------------------------------------------------  *
 *  |       F30         |       F31         |          *
 *  -------------------------------------------------  *
 *  |      512–519      |      520–527      |          *
 *  -------------------------------------------------  *
 *                                                     *
 *  Total frame size: 528 bytes                        *
 *  (184 GPR/CR/LR/PC + 8 pad + 192 VMX + 144 FPR)    *
 *  (v20-v31, f14-f31 non-volatile per ppc64 ELF ABI)  *
 *                                                     *
 *******************************************************/

.file "jump_ppc64_sysv_elf_gas.S"
.globl jump_fcontext
.hidden jump_fcontext
#if _CALL_ELF == 2
	.text
	.align 2
jump_fcontext:
        # ELFv2: no TOC setup preamble — jump_fcontext has no TOC references.
        # .localentry offset 0 (global entry == local entry) prevents the linker
        # from generating a frame-allocating long-branch thunk that would corrupt
        # the context switch: a thunk with stdu/bl pushes its own frame onto r1,
        # so the LR saved at fctx+168 points back into the thunk; on resume
        # the bctr lands in the thunk which then does addi r1,r1,32 against the
        # wrong stack, leading to bctr -> 0x0.
        .localentry jump_fcontext, 0
#else
	.section ".opd","aw"
	.align 3
jump_fcontext:
# ifdef _CALL_LINUX
        .quad   .L.jump_fcontext,.TOC.@tocbase,0
        .type   jump_fcontext,@function
        .text
        .align 2
.L.jump_fcontext:
# else
        .hidden .jump_fcontext
        .globl  .jump_fcontext
        .quad   .jump_fcontext,.TOC.@tocbase,0
        .size   jump_fcontext,24
        .type   .jump_fcontext,@function
        .text
        .align 2
.jump_fcontext:
# endif
#endif
    # reserve space on stack
    # frame must be a multiple of 16 to keep r1 16-byte aligned (ABI requirement).
    # 184 (GPR/CR/LR/PC) + 192 (12 VMX × 16) + 144 (18 FPR × 8) = 520; round up to 528.
    subi  %r1, %r1, 528

#if _CALL_ELF != 2
    std  %r2,  0(%r1)  # save TOC
#endif
    std  %r14, 8(%r1)  # save R14
    std  %r15, 16(%r1)  # save R15
    std  %r16, 24(%r1)  # save R16
    std  %r17, 32(%r1)  # save R17
    std  %r18, 40(%r1)  # save R18
    std  %r19, 48(%r1)  # save R19
    std  %r20, 56(%r1)  # save R20
    std  %r21, 64(%r1)  # save R21
    std  %r22, 72(%r1)  # save R22
    std  %r23, 80(%r1)  # save R23
    std  %r24, 88(%r1)  # save R24
    std  %r25, 96(%r1)  # save R25
    std  %r26, 104(%r1)  # save R26
    std  %r27, 112(%r1)  # save R27
    std  %r28, 120(%r1)  # save R28
    std  %r29, 128(%r1)  # save R29
    std  %r30, 136(%r1)  # save R30
    std  %r31, 144(%r1)  # save R31
#if _CALL_ELF != 2
    std  %r3,  152(%r1)  # save hidden
#endif

    # save CR
    mfcr  %r0
    std   %r0, 160(%r1)
    # save LR
    mflr  %r0
    std   %r0, 168(%r1)
    # save LR as PC
    std   %r0, 176(%r1)

    # save F14-F31: non-volatile FPRs per ppc64 ELF ABI
    # stfd uses a signed 16-bit displacement directly off r1 — no index register needed.
    # FPR area starts at 384 (after 8-byte VMX alignment pad at 184-191).
    stfd  %f14, 384(%r1)
    stfd  %f15, 392(%r1)
    stfd  %f16, 400(%r1)
    stfd  %f17, 408(%r1)
    stfd  %f18, 416(%r1)
    stfd  %f19, 424(%r1)
    stfd  %f20, 432(%r1)
    stfd  %f21, 440(%r1)
    stfd  %f22, 448(%r1)
    stfd  %f23, 456(%r1)
    stfd  %f24, 464(%r1)
    stfd  %f25, 472(%r1)
    stfd  %f26, 480(%r1)
    stfd  %f27, 488(%r1)
    stfd  %f28, 496(%r1)
    stfd  %f29, 504(%r1)
    stfd  %f30, 512(%r1)
    stfd  %f31, 520(%r1)

    # save VS63-VS52 (v31-v20): non-volatile VMX registers per ppc64 ELF ABI
    # stvx EA = r1 + r0; r1 is 16-byte aligned per ABI; offsets start at 192
    # (= 12 × 16), so every EA is a true multiple of 16.  No silent masking.
    # r0 is used as the index register (it is caller-saved / volatile here).
    li    %r0, 192
    stvx  %v31, %r1, %r0    # save VS63 / v31
    li    %r0, 208
    stvx  %v30, %r1, %r0    # save VS62 / v30
    li    %r0, 224
    stvx  %v29, %r1, %r0    # save VS61 / v29
    li    %r0, 240
    stvx  %v28, %r1, %r0    # save VS60 / v28
    li    %r0, 256
    stvx  %v27, %r1, %r0    # save VS59 / v27
    li    %r0, 272
    stvx  %v26, %r1, %r0    # save VS58 / v26
    li    %r0, 288
    stvx  %v25, %r1, %r0    # save VS57 / v25
    li    %r0, 304
    stvx  %v24, %r1, %r0    # save VS56 / v24
    li    %r0, 320
    stvx  %v23, %r1, %r0    # save VS55 / v23
    li    %r0, 336
    stvx  %v22, %r1, %r0    # save VS54 / v22
    li    %r0, 352
    stvx  %v21, %r1, %r0    # save VS53 / v21
    li    %r0, 368
    stvx  %v20, %r1, %r0    # save VS52 / v20

    # store RSP (pointing to context-data) in R6
    mr  %r6, %r1

#if _CALL_ELF == 2
    # restore RSP (pointing to context-data) from R3
    mr  %r1, %r3
#else
    # restore RSP (pointing to context-data) from R4
    mr  %r1, %r4

    ld  %r2,  0(%r1)  # restore TOC
#endif

    # restore F14-F31: non-volatile FPRs per ppc64 ELF ABI
    lfd   %f14, 384(%r1)
    lfd   %f15, 392(%r1)
    lfd   %f16, 400(%r1)
    lfd   %f17, 408(%r1)
    lfd   %f18, 416(%r1)
    lfd   %f19, 424(%r1)
    lfd   %f20, 432(%r1)
    lfd   %f21, 440(%r1)
    lfd   %f22, 448(%r1)
    lfd   %f23, 456(%r1)
    lfd   %f24, 464(%r1)
    lfd   %f25, 472(%r1)
    lfd   %f26, 480(%r1)
    lfd   %f27, 488(%r1)
    lfd   %f28, 496(%r1)
    lfd   %f29, 504(%r1)
    lfd   %f30, 512(%r1)
    lfd   %f31, 520(%r1)

    # restore VS52-VS63 (v20-v31): non-volatile VMX registers per ppc64 ELF ABI
    li    %r0, 368
    lvx   %v20, %r1, %r0    # restore VS52 / v20
    li    %r0, 352
    lvx   %v21, %r1, %r0    # restore VS53 / v21
    li    %r0, 336
    lvx   %v22, %r1, %r0    # restore VS54 / v22
    li    %r0, 320
    lvx   %v23, %r1, %r0    # restore VS55 / v23
    li    %r0, 304
    lvx   %v24, %r1, %r0    # restore VS56 / v24
    li    %r0, 288
    lvx   %v25, %r1, %r0    # restore VS57 / v25
    li    %r0, 272
    lvx   %v26, %r1, %r0    # restore VS58 / v26
    li    %r0, 256
    lvx   %v27, %r1, %r0    # restore VS59 / v27
    li    %r0, 240
    lvx   %v28, %r1, %r0    # restore VS60 / v28
    li    %r0, 224
    lvx   %v29, %r1, %r0    # restore VS61 / v29
    li    %r0, 208
    lvx   %v30, %r1, %r0    # restore VS62 / v30
    li    %r0, 192
    lvx   %v31, %r1, %r0    # restore VS63 / v31

    ld  %r14, 8(%r1)  # restore R14
    ld  %r15, 16(%r1)  # restore R15
    ld  %r16, 24(%r1)  # restore R16
    ld  %r17, 32(%r1)  # restore R17
    ld  %r18, 40(%r1)  # restore R18
    ld  %r19, 48(%r1)  # restore R19
    ld  %r20, 56(%r1)  # restore R20
    ld  %r21, 64(%r1)  # restore R21
    ld  %r22, 72(%r1)  # restore R22
    ld  %r23, 80(%r1)  # restore R23
    ld  %r24, 88(%r1)  # restore R24
    ld  %r25, 96(%r1)  # restore R25
    ld  %r26, 104(%r1)  # restore R26
    ld  %r27, 112(%r1)  # restore R27
    ld  %r28, 120(%r1)  # restore R28
    ld  %r29, 128(%r1)  # restore R29
    ld  %r30, 136(%r1)  # restore R30
    ld  %r31, 144(%r1)  # restore R31
#if _CALL_ELF != 2
    ld  %r3,  152(%r1)  # restore hidden
#endif

    # restore CR
    ld  %r0, 160(%r1)
    mtcr  %r0
    # restore LR
    ld  %r0, 168(%r1)
    mtlr  %r0

    # load PC
    ld  %r12, 176(%r1)
    # restore CTR
    mtctr  %r12

    # adjust stack
    addi  %r1, %r1, 528

#if _CALL_ELF == 2
    # copy transfer_t into transfer_fn arg registers
    mr  %r3, %r6
    # arg pointer already in %r4

    # jump to context
    bctr
	.size jump_fcontext, .-jump_fcontext
#else
    # zero in r3 indicates first jump to context-function
    cmpdi %r3, 0
    beq use_entry_arg

    # return transfer_t
    std  %r6, 0(%r3)
    std  %r5, 8(%r3)

    # jump to context
    bctr

use_entry_arg:
    # copy transfer_t into transfer_fn arg registers
    mr  %r3, %r6
    mr  %r4, %r5

    # jump to context
    bctr
# ifdef _CALL_LINUX
	.size .jump_fcontext, .-.L.jump_fcontext
# else
	.size .jump_fcontext, .-.jump_fcontext
# endif
#endif


/* Mark that we don't need executable stack.  */
.section .note.GNU-stack,"",%progbits
